import 'dart:typed_data';

import 'package:readright/audio/stt/pronunciation_assessor.dart';

/// Cloud assessor for Speechace (https://www.speechace.com/). 
/// Implement provider-specific logic here.
/// Implementations should accept WAV bytes or PCM as required by the vendor.
class SpeechAceAssessor implements PronunciationAssessor {
  final String endpointOrConfig;

  SpeechAceAssessor({required this.endpointOrConfig});

  @override
  Future<AssessmentResult> assess({
    required String referenceText,
    required Uint8List audioBytes,
    required String locale
  }) async {
    // TODO: implement provider-specific upload/streaming and parsing of transcription
    throw UnimplementedError('SpeechAceAssessor.assess not implemented - add provider logic');
  }
}
