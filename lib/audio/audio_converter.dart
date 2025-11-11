import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Small helpers for common audio conversions.
///
/// These helpers prefer platform-native converters (via a MethodChannel)
/// and a lightweight Dart-based PCM->WAV wrapper. There is NO FFmpeg
/// fallback in this file — if a requested conversion isn't available
/// natively or fails, the methods will throw an error.
/// 
/// ChatGPT: This class was generated with the help of ChatGPT to handle
/// audio format conversions and avoid FFmpeg conversions due to performance
/// concerns with build and runtime for the app.

class AudioConverter {
  static const MethodChannel _channel = MethodChannel('readright/audio_converter');

  // Helper: write a basic WAV header and concatenate raw PCM data.
  // Assumes signed 16-bit little-endian PCM input.
  static Future<void> _wrapPcmToWav(String pcmPath, String wavPath, {int sampleRate = 16000, int channels = 1, int bitsPerSample = 16}) async {
    final pcmFile = File(pcmPath);
    final wavFile = File(wavPath);
    final pcmBytes = await pcmFile.readAsBytes();

    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = (channels * (bitsPerSample ~/ 8));
    final dataSize = pcmBytes.length;

    final header = BytesBuilder();
    // RIFF header
    header.add(ascii.encode('RIFF'));
    header.add(_u32ToBytes(36 + dataSize)); // file size - 8
    header.add(ascii.encode('WAVE'));
    // fmt subchunk
    header.add(ascii.encode('fmt '));
    header.add(_u32ToBytes(16)); // subchunk1 size
    header.add(_u16ToBytes(1)); // audio format PCM = 1
    header.add(_u16ToBytes(channels));
    header.add(_u32ToBytes(sampleRate));
    header.add(_u32ToBytes(byteRate));
    header.add(_u16ToBytes(blockAlign));
    header.add(_u16ToBytes(bitsPerSample));
    // data subchunk
    header.add(ascii.encode('data'));
    header.add(_u32ToBytes(dataSize));

    await wavFile.writeAsBytes(header.toBytes() + pcmBytes, flush: true);
  }

  static List<int> _u16ToBytes(int value) {
    return [value & 0xff, (value >> 8) & 0xff];
  }

  static List<int> _u32ToBytes(int value) {
    return [value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff];
  }

  /// Convert WAV -> AAC
  static Future<String> convertWavToAac(String wavPath, String aacPath, {int sampleRate = 16000, int bitrateK = 64}) async {
    debugPrint('debug: converting WAV -> AAC: $wavPath -> $aacPath');
    // Try platform-native conversion first (iOS/Android). If not available,
    if ((Platform.isIOS || Platform.isAndroid)) {
      try {
        final args = {
          'wavPath': wavPath,
          'aacPath': aacPath,
          'sampleRate': sampleRate,
          'bitrateK': bitrateK,
        };
        final res = await _channel.invokeMethod<bool>('convertWavToAac', args);
        if (res == true) {
          debugPrint('debug: WAV->AAC native conversion succeeded: $aacPath');
          return aacPath;
        }
        throw Exception('native WAV->AAC conversion returned false');
      } catch (e, st) {
        debugPrint('debug: native WAV->AAC conversion failed: $e\n$st');
        rethrow;
      }
    }

    throw UnsupportedError('WAV->AAC conversion is only supported on iOS/Android via the native converter.');
  }

  /// Convert PCM -> WAV
  static Future<String> convertPcmToWav(String pcmPath, String wavPath, {int sampleRate = 16000}) async {
    debugPrint('debug: converting PCM -> WAV: $pcmPath -> $wavPath');

    // Prefer local Dart-based WAV wrapping for raw PCM (fast) to avoid invoking
    // native tools. This simply writes a WAV header and appends PCM data.
    if (pcmPath == wavPath) {
      throw Exception('debug: PCM->WAV conversion aborted: input and output paths are identical: $pcmPath');
    }

    await _wrapPcmToWav(pcmPath, wavPath, sampleRate: sampleRate, channels: 1, bitsPerSample: 16);
    debugPrint('debug: PCM->WAV wrapper succeeded: $wavPath');
    return wavPath;
  }

  /// Convert PCM -> AAC
  static Future<String> convertPcmToAac(String pcmPath, String aacPath, {int sampleRate = 16000, int bitrateK = 64}) async {
    debugPrint('debug: converting PCM -> AAC: $pcmPath -> $aacPath');

    // Implement via native WAV->AAC on mobile. Wrap raw PCM to a temporary WAV,
    // then ask platform to convert WAV->AAC.
    final tmpDir = Directory.systemTemp;
    final wavPath = File('${tmpDir.path}/${DateTime.now().microsecondsSinceEpoch}.wav').path;
    try {
      await _wrapPcmToWav(pcmPath, wavPath, sampleRate: sampleRate, channels: 1, bitsPerSample: 16);

      if ((Platform.isIOS || Platform.isAndroid)) {
        final args = {
          'wavPath': wavPath,
          'aacPath': aacPath,
          'sampleRate': sampleRate,
          'bitrateK': bitrateK,
        };
        final res = await _channel.invokeMethod<bool>('convertWavToAac', args);
        if (res == true) {
          debugPrint('debug: PCM->AAC native conversion succeeded: $aacPath');
          return aacPath;
        }
        throw Exception('native PCM->AAC conversion failed or returned false');
      }

      throw UnsupportedError('PCM->AAC conversion is only supported on iOS/Android via the native converter.');
    } finally {
      try {
        final f = File(wavPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
