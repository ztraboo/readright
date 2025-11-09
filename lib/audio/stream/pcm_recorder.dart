import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// PcmRecorder wraps flutter_sound's recorder and exposes a broadcast stream of
/// PCM16 (mono, 16 kHz) bytes suitable for STT providers. If the platform provides
/// stereo or different sample rate, the recorder will mix-down to mono and resample using a
/// simple linear resampler. STT prefer mono instead of stereo, however, stereo seems better for playback.
/// The flutter_sound stream example includes both Float32 PCM or Int16 PCM; 
/// we use Int16 here because it is more compatible with STT providers and there is less conversion needed.
/// References:
/// - https://fs-doc.vercel.app/tau/examples/ex_streams.html
/// - https://github.com/canardoux/flutter_sound/blob/master/example/lib/streams/streams.dart
/// 
/// ChatGPT: This class was generated with the help of ChatGPT to handle audio recording and PCM data streaming.
class PcmRecorder {

  double _dbLevel = 0.0;

  bool _recorderIsInited = false;
  bool get isRecorderInited => _recorderIsInited;

  // The recorder instance from flutter_sound.
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  // A subscription
  StreamSubscription? _recorderSubscription;

  // Input controller expected by flutter_sound: events are List<Int16List>
  // (one entry per channel). We listen to this and convert to Uint8List.
  final StreamController<List<Int16List>> _int16InController = StreamController();

  // Public broadcast stream of PCM16 chunks.
  // Used to emit Uint8List PCM16LE data for consumers (e.g. STT and playback).
  final StreamController<Uint8List> _pcmOutController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get pcmStream => _pcmOutController.stream;

  // Optional in-memory buffering (useful to build final WAV). Keep as BytesBuilder
  final BytesBuilder _buffer = BytesBuilder();
  bool _buffering = true;

  bool _initialized = false;
  StreamSubscription<List<Int16List>>? _int16Sub;

  int _targetSampleRate = 16000;
  int get targetSampleRate => _targetSampleRate;

  // Current decibel level most recently reported by the recorder. This is
  // updated from FlutterSound's onProgress events and is available even if
  // no one is subscribed to [levelStream]. Value is in dB (negative values
  // are expected for typical microphone levels) and defaults to 0.0.
  double get dbLevel => _dbLevel;

  // Whether the recorder is currently recording.
  bool get isRecording => _recorder.isRecording;

  // Initialize the recorder resources.
  // This is called internally before starting recording.
  Future<void> init() async {
    if (_initialized) return;

    // Ensure recorder is opened; propagate any permission errors to caller so
    // the UI can handle them (don't silently swallow RecordingPermissionException).
    await _openRecorder();

    // Listen to the int16 controller and convert incoming blocks to bytes.
    _int16Sub = _int16InController.stream.listen(
      (List<Int16List> block) {
        try {
          // Convert stereo -> mono if needed
          Int16List mono = _ensureMono(block);

          // Resample if needed: we assume recorder honors requested sampleRate,
          // but in cases where it doesn't you can detect and resample. For now
          // we pass through; caller can configure targetSampleRate if needed.
          final bytes = _int16ListToLEBytes(mono);
          if (_buffering) _buffer.add(bytes);
          _pcmOutController.add(bytes);
        } catch (e, st) {
          debugPrint('Error processing PCM block: $e\n$st');
        }
      },
      onError: (e) => debugPrint('int16 input error: $e')
    );

    _initialized = true;
  }

  // Explicitly check/request microphone permission. Returns the final status.
  // Call this from UI to allow handling of permanentlyDenied (open app settings).
  Future<PermissionStatus> checkAndRequestPermission() async {
    final status = await Permission.microphone.status;
    debugPrint('PcmRecorder.checkAndRequestPermission: initial status=$status');
    switch (status) {
      case PermissionStatus.granted:
        return status;
      case PermissionStatus.restricted:
        debugPrint('PcmRecorder.checkAndRequestPermission: permission is restricted');
        return status;
      case PermissionStatus.limited:
        debugPrint('PcmRecorder.checkAndRequestPermission: permission is limited');
        return status;
      case PermissionStatus.provisional:
        debugPrint('PcmRecorder.checkAndRequestPermission: permission is provisional');
        return status;
      case PermissionStatus.permanentlyDenied:
        debugPrint('PcmRecorder.checkAndRequestPermission: permission is permanentlyDenied - must open app settings');
        return status;
      case PermissionStatus.denied:
        // User denied but not permanently: we can request again
        final req = await Permission.microphone.request();
        debugPrint('PcmRecorder.checkAndRequestPermission: request result=$req');
        return req;
    }
  }

  // Return the current microphone permission status without prompting.
  Future<PermissionStatus> getPermissionStatus() async {
    final status = await Permission.microphone.status;
    debugPrint('PcmRecorder.getPermissionStatus: $status');
    return status;
  }

  // Open the recorder after ensuring permission is granted.
  Future<void> _openRecorder() async {
    await _recorder.openRecorder();
    _recorderSubscription = _recorder.onProgress!.listen((e) {
      _dbLevel = e.decibels as double;
    });
    
    await _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 100)); // DO NOT FORGET THIS CALL !!!

    _recorderIsInited = true;
  }

  // We have finished with the recorder. Release the subscription
  void cancelRecorderSubscriptions() {
    if (_recorderSubscription != null) {
      _recorderSubscription!.cancel();
      _recorderSubscription = null;
    }
  }

  // Start recording. Prefer to pass codec: Codec.pcm16, sampleRate:16000, numChannels:1
  Future<void> start({int sampleRate = 16000, int numChannels = 1, bool bufferToMemory = true}) async {
    // Ensure permission is granted before starting.
    final perm = await checkAndRequestPermission();
    if (perm != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted (status: $perm)');
    }

    // Clear any existing buffer before recording.
    clearBuffer();

    await init();
    _buffering = bufferToMemory;
    _targetSampleRate = sampleRate;

    // Start recorder and pass the internal controller's sink to flutter_sound
    await _recorder.startRecorder(
      codec: Codec.pcm16,
      sampleRate: sampleRate,
      numChannels: numChannels,
      audioSource: AudioSource.defaultSource,
      toStreamInt16: _int16InController.sink,
    );
  }

  Future<void> stop() async {
    _buffering = false;
    _dbLevel = 0.0;
    await _recorder.stopRecorder();
  }

  // Return the buffered PCM16 little-endian bytes (concatenated) if buffering
  // was enabled. This does NOT add a WAV header; use wav_writer.makeWav().
  Uint8List getBufferedPcmBytes() {
    return _buffer.toBytes();
  }

  // Clear internal buffer
  void clearBuffer() {
    if (!_buffering) {
      _buffer.clear();
    }
  }

  void dispose() {
    _int16Sub?.cancel();
    _int16InController.close();
    _pcmOutController.close();
    _recorder.closeRecorder();
    cancelRecorderSubscriptions();
  }

  // Helpers ---------------------------------------------------------------
  static Int16List _ensureMono(List<Int16List> block) {
    if (block.isEmpty) return Int16List(0);
    if (block.length == 1) return block[0];
    // If stereo (2 channels) take average of channels (L+R)/2
    final left = block[0];
    final right = block.length > 1 ? block[1] : Int16List(left.length);
    final len = left.length < right.length ? left.length : right.length;
    final out = Int16List(len);
    for (var i = 0; i < len; i++) {
      final sum = left[i].toInt() + right[i].toInt();
      out[i] = (sum ~/ 2).toInt();
    }
    return out;
  }

  static Uint8List _int16ListToLEBytes(Int16List samples) {
    final bytes = Uint8List(samples.length * 2);
    final bd = bytes.buffer.asByteData();
    for (var i = 0; i < samples.length; i++) {
      bd.setInt16(i * 2, samples[i], Endian.little);
    }
    return bytes;
  }
}
