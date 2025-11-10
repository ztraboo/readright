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
