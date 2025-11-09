import 'dart:convert';
import 'dart:typed_data';

/// Helper to write out WAV files from PCM16LE bytes.
/// ChatGPT: This function was generated with the help of ChatGPT to create WAV headers for PCM data.

Uint8List _u16ToBytes(int v) {
  final b = ByteData(2);
  b.setUint16(0, v, Endian.little);
  return b.buffer.asUint8List();
}

Uint8List _u32ToBytes(int v) {
  final b = ByteData(4);
  b.setUint32(0, v, Endian.little);
  return b.buffer.asUint8List();
}

/// Build a RIFF/WAV header and prepend to pcm16LE bytes.
Uint8List makeWav(Uint8List pcm16LEBytes, {int sampleRate = 16000, int channels = 1, int bitsPerSample = 16}) {
  final pcmLen = pcm16LEBytes.length;
  final header = BytesBuilder();

  header.add(ascii.encode('RIFF'));
  header.add(_u32ToBytes(36 + pcmLen)); // file size - 8
  header.add(ascii.encode('WAVE'));

  // fmt chunk
  header.add(ascii.encode('fmt '));
  header.add(_u32ToBytes(16)); // Subchunk1Size
  header.add(_u16ToBytes(1)); // AudioFormat = 1 (PCM)
  header.add(_u16ToBytes(channels));
  header.add(_u32ToBytes(sampleRate));
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  header.add(_u32ToBytes(byteRate));
  final blockAlign = channels * (bitsPerSample ~/ 8);
  header.add(_u16ToBytes(blockAlign));
  header.add(_u16ToBytes(bitsPerSample));

  // data chunk
  header.add(ascii.encode('data'));
  header.add(_u32ToBytes(pcmLen));

  final out = BytesBuilder();
  out.add(header.toBytes());
  out.add(pcm16LEBytes);
  return out.toBytes();
}
