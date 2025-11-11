import 'dart:typed_data';

import 'package:readright/audio/stt/pronunciation_assessor.dart';

/// Cloud assessor for Azure Speech (https://azure.microsoft.com/en-us/products/ai-services/ai-speech). 
/// Implement provider-specific logic here.
/// Implementations should accept WAV bytes or PCM as required by the vendor.
class AzureSpeechAssessor implements PronunciationAssessor {
  final String endpointOrConfig;

  AzureSpeechAssessor({required this.endpointOrConfig});

  @override
  Future<AssessmentResult> assess({
    required String referenceText,
    required Uint8List audioBytes,
    required String locale
  }) async {
    // TODO: implement provider-specific upload/streaming and parsing of transcription
    throw UnimplementedError('AzureSpeechAssessor.assess not implemented - add provider logic');
  }
}
