import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:cheetah_flutter/cheetah.dart';

import 'package:readright/audio/stream/pcm_recorder.dart';
import 'package:readright/audio/stt/pronunciation_assessor.dart';

/// On-device assessor for Cheetah (https://picovoice.ai/platform/cheetah/). 
/// Implement provider-specific logic here.
/// Implementations should accept WAV bytes or PCM as required by the vendor.

/// A lightweight local assessor that subscribes to a [PcmRecorder]'s
/// `pcmStream` and computes simple transcription metrics for pronounced word.
class CheetahAssessor implements PronunciationAssessor {
  String accessKey = 'ptQzT1bn5rGVtfHhjX/fUqqamdgh+Q0C1apku5C90SCpt81J5aRGdw==';  // AccessKey obtained from Picovoice Console (https://console.picovoice.ai/)
  String modelPath = 'data/Cheetah_ReadRight.pv'; // path relative to the assets folder or absolute path to file on device

  Cheetah? _cheetah;

  final PcmRecorder pcmRecorder;
  final String practiceWord;

  StreamSubscription<Uint8List>? _sub;
  // Expose assessment results as a broadcast stream so callers (UI) can
  // subscribe and receive transcripts produced from recorded audio chunks.
  final StreamController<AssessmentResult> _controller = StreamController<AssessmentResult>.broadcast();

  /// Broadcast stream of assessment results. UI code can listen to this to
  /// display partial or final transcripts.
  Stream<AssessmentResult> get stream => _controller.stream;

  // /// Exposed broadcast stream of assessment results.
  // Stream<AssessmentResult> get stream => _controller.stream;

  /// A light exponential smoothing factor applied to RMS values to make the
  /// reported dB values less jumpy. Values closer to 1.0 smooth more.
  // final double smoothing;
  // double _smoothedRms = 0.0;

  // CheetahAssessor({this.smoothing = 0.2});
  CheetahAssessor({
    required this.pcmRecorder,
    required this.practiceWord,
  });

  Future<void> createCheetah() async {
    try {
      _cheetah = await Cheetah.create(accessKey, modelPath);
    } catch (err) {
      // handle Cheetah init error
      debugPrint('CheetahAssessor: failed to initialize Cheetah: $err');
    }
  }

  /// Start listening to [recorder]'s `pcmStream` and emit assessment events.
  ///
  /// Calling start multiple times will cancel an existing subscription first.
  Future<void> start() async {
    // Initialize Cheetah instance
    await createCheetah();

    await pcmRecorder.init();
    // Subscribe to PCM stream and perform an assess per chunk. Results are
    // emitted to the `_controller` so callers can react (UI updates, logs).
    _sub = pcmRecorder.pcmStream.listen((chunk) async {
      try {
        final result = await assess(referenceText: practiceWord, audioBytes: chunk, locale: 'en-US');
        // Emit result to any listeners.
        if (!_controller.isClosed) _controller.add(result);
      } catch (err, st) {
        debugPrint('CheetahAssessor: assess error: $err\n$st');
      }
    }, onError: (e) {
      debugPrint('CheetahAssessor: recorder stream error: $e');
    });
  }

  @override
  Future<AssessmentResult> assess({
    required String referenceText,
    required Uint8List audioBytes,
    required String locale
  }) async {
    // Cheetah specific logic to process audioBytes and return an AssessmentResult.
    String transcript = '';
    int framesProcessed = 0;

    if (audioBytes.isEmpty) {
      throw ArgumentError('CheetahAssessor.assess: audioBytes is empty');
    }

    // Ensure Cheetah is initialized.
    if (_cheetah == null) {
      await createCheetah();
      if (_cheetah == null) {
        throw StateError('Cheetah instance could not be initialized');
      }
    }

    // debugPrint('CheetahAssessor: assessing audioBytes with referenceText="$referenceText"');

    // Convert raw PCM bytes (little-endian 16-bit) to Int16List view.
    final samples = PcmRecorder.bytesToInt16List(audioBytes);

    // Cheetah requires frames of a fixed length; process the samples in chunks
    // of that frame length and pad the final frame with zeros if necessary.
    final int frameLength = _cheetah!.frameLength;
    int offset = 0;

    while (offset + frameLength <= samples.length) {
      final frame = Int16List.fromList(samples.sublist(offset, offset + frameLength));
      CheetahTranscript partialResult = await _cheetah!.process(frame);
      transcript += partialResult.transcript;
      framesProcessed++;
      offset += frameLength;
    }

    final int remaining = samples.length - offset;
    if (remaining > 0) {
      final padded = Int16List(frameLength);
      for (int i = 0; i < remaining; i++) {
        padded[i] = samples[offset + i];
      }
      CheetahTranscript partialResult = await _cheetah!.process(padded);
      transcript += partialResult.transcript;
      framesProcessed++;
    }

    // Ensure we flush the model to retrieve any remaining transcript buffered
    // internally by Cheetah (some streaming STT engines only return final text
    // on a flush/finalize call).
    try {
      final CheetahTranscript finalResult = await _cheetah!.flush();
      if (finalResult.transcript.isNotEmpty) {
        if (transcript.isNotEmpty && !transcript.endsWith(' ')) {
          transcript = '$transcript ';
        }
        transcript += finalResult.transcript;

        debugPrint("----------------------------------------------------");
        debugPrint('CheetahAssessor: transcript="$transcript"');
        debugPrint("----------------------------------------------------");
      }
    } catch (err) {
      debugPrint('CheetahAssessor: flush error: $err');
    }

    // TODO: compute confidence and score based on referenceText vs transcript.
    double confidence = 0.0;
    double score = 0.0;

    return AssessmentResult(
      recognizedText: transcript,
      confidence: confidence,
      score: score,
      details: {
        'source': 'cheetah_full_assess',
        'timestamp': DateTime.now().toIso8601String(),
        'frames': framesProcessed,
      },
    );
  }

  /// Stop listening and close resources. After calling stop, you can call
  /// start(...) again to re-subscribe.
  Future<void> stop() async {
    if (_sub != null) {
      await _sub!.cancel();
      _sub = null;
    }
  }

  /// Dispose resources; after this the instance should not be used.
  Future<void> dispose() async {
    await stop();
    // await _controller.close();

    if (!_controller.isClosed) await _controller.close();

    await _cheetah?.delete();
  }

}
