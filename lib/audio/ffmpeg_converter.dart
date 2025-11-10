import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

/// Small helpers that wrap FFmpegKit commands for common audio conversions.
/// These are intentionally simple, throwing on failure and returning the
/// output path on success.

class FfmpegConverter {
  /// Convert AAC -> WAV
  static Future<String> convertAacToWav(String aacPath, String wavPath, {int sampleRate = 16000}) async {
    debugPrint('debug: converting AAC -> WAV: $aacPath -> $wavPath');
    final cmd = '-y -i "$aacPath" -ar $sampleRate -ac 1 -acodec pcm_s16le "$wavPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('debug: AAC->WAV conversion succeeded: $wavPath');
      return wavPath;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      final logs = await session.getAllLogsAsString();
      throw Exception('debug: FFmpeg AAC->WAV conversion failed: returnCode=$returnCode, failStack=$failStackTrace, logs=$logs');
    }
  }

  /// Convert WAV -> AAC
  static Future<String> convertWavToAac(String wavPath, String aacPath, {int sampleRate = 16000, int bitrateK = 64}) async {
    debugPrint('debug: converting WAV -> AAC: $wavPath -> $aacPath');
    final cmd = '-y -i "$wavPath" -ar $sampleRate -ac 1 -c:a aac -b:a ${bitrateK}k "$aacPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('debug: WAV->AAC conversion succeeded: $aacPath');
      return aacPath;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      final logs = await session.getAllLogsAsString();
      throw Exception('debug: FFmpeg WAV->AAC conversion failed: returnCode=$returnCode, failStack=$failStackTrace, logs=$logs');
    }
  }

  /// Convert PCM -> WAV
  static Future<String> convertPcmToWav(String pcmPath, String wavPath, {int sampleRate = 16000}) async {
    debugPrint('debug: converting PCM -> WAV: $pcmPath -> $wavPath');
    final cmd = '-y -f s16le -ar $sampleRate -ac 1 -i "$pcmPath" -c:a pcm_s16le "$wavPath"';

    // Guard: ensure output path is not identical to the input path
    if (pcmPath == wavPath) {
      throw Exception('debug: PCM->WAV conversion aborted: input and output paths are identical: $pcmPath');
    }

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('debug: PCM->WAV conversion succeeded: $wavPath');
      return wavPath;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      final logs = await session.getAllLogsAsString();
      throw Exception('debug: FFmpeg PCM->WAV conversion failed: returnCode=$returnCode, failStack=$failStackTrace, logs=$logs');
    }
  }

  /// Convert PCM -> AAC
  static Future<String> convertPcmToAac(String pcmPath, String aacPath, {int sampleRate = 16000, int bitrateK = 64}) async {
    debugPrint('debug: converting PCM -> AAC: $pcmPath -> $aacPath');

    // -f s16le: input is raw signed 16-bit little-endian PCM
    // -ar <sampleRate>: set sample rate
    // -ac 1: mono
    // -c:a aac -b:a <bitrate>: encode to AAC at provided bitrate
    final cmd = '-y -f s16le -ar $sampleRate -ac 1 -i "$pcmPath" -c:a aac -b:a ${bitrateK}k "$aacPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('debug: PCM->AAC conversion succeeded: $aacPath');
      return aacPath;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      final logs = await session.getAllLogsAsString();
      throw Exception('debug: FFmpeg PCM->AAC conversion failed: returnCode=$returnCode, failStack=$failStackTrace, logs=$logs');
    }
  }
}
