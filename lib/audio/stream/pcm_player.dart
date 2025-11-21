import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

import 'pcm_recorder.dart';

/// PcmPlayer subscribes to a [PcmRecorder] and plays incoming PCM16LE chunks
/// using flutter_sound's streaming player. It also supports playing a buffered
/// Uint8List (single WAV-less PCM16LE payload) by feeding it to the player.
/// 
/// ChatGPT: This class was generated with the help of ChatGPT to handle audio playing from PCM data streaming.
class PcmPlayer {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription<Uint8List>? _sub;
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    await _player.openPlayer();
    _inited = true;
  }

  // Play a buffered PCM16LE payload (no WAV header) by streaming it to the player.
  Future<void> playBufferedPcm(Uint8List pcm16leBytes, {int sampleRate = 16000}) async {
    await init();

    if (!_player.isStopped) {
      await _player.stopPlayer();
    }

    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: sampleRate,
      numChannels: 1,
      interleaved: true,
      bufferSize: 2048,
    );

    // Simple software gain: amplify 16-bit little-endian PCM samples in-place.
    // 1.0 = no change, >1.0 = louder (clipped to int16 range).
    const double gain = 6.0;
    if (gain != 1.0) {
      // Work on a copy so we don't modify the caller's buffer (avoids cumulative amplification).
      final Uint8List amplified = Uint8List.fromList(pcm16leBytes);
      for (int i = 0; i + 1 < amplified.length; i += 2) {
      final int lo = amplified[i];
      final int hi = amplified[i + 1];
      int sample = (hi << 8) | lo;
      if ((sample & 0x8000) != 0) sample = sample - 0x10000; // sign extend
      int amplifiedSample = (sample * gain).round();
      if (amplifiedSample > 0x7fff) amplifiedSample = 0x7fff;
      if (amplifiedSample < -0x8000) amplifiedSample = -0x8000;
      final int out = amplifiedSample & 0xffff;
      amplified[i] = out & 0xff;
      amplified[i + 1] = (out >> 8) & 0xff;
      }
      // Repoint the buffer used by the feed loop below to the amplified copy.
      pcm16leBytes = amplified;
    }

    // Feed the buffer in slices to avoid large synchronous writes
    const int chunkSize = 4096;
    int offset = 0;
    while (offset < pcm16leBytes.length) {
      final end = (offset + chunkSize) < pcm16leBytes.length ? offset + chunkSize : pcm16leBytes.length;
      final slice = pcm16leBytes.sublist(offset, end);
      await _player.feedUint8FromStream(slice);
      offset = end;
    }
  }

  // Stop live playback and cancel subscription.
  Future<void> stop() async {
    if (_sub != null) {
      await _sub!.cancel();
      _sub = null;
    }
    if (!_player.isStopped) {
      await _player.stopPlayer();
    }
  }

  void dispose() {
    _sub?.cancel();
    _player.closePlayer();
  }
}
