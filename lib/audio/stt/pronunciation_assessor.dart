import 'dart:typed_data';

/// Result returned by a PronunciationAssessor implementation.
class AssessmentResult {
  final String recognizedText;
  final double confidence; // 0..1 if available
  final double score; // normalized similarity 0..1
  final Map<String, dynamic>? details;

  AssessmentResult({
    required this.recognizedText,
    required this.confidence,
    required this.score,
    this.details,
  });
}

/// Abstraction for pronunciation assessment providers.
/// Implementations may be on-device or cloud-based. The contract expects
/// callers to pass final audio as WAV bytes (RIFF PCM 16) or raw PCM depending
/// on implementation. Document which format your implementation expects.
abstract class PronunciationAssessor {
  /// Assess a final audio clip against a reference string.
  Future<AssessmentResult> assess({
    required String referenceText,
    required Uint8List audioBytes,
    required String locale, // e.g., en-US
  });

  /// Optional: implementations may provide streaming APIs separately.
}


