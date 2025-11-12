
import 'package:readright/utils/enums.dart';
import 'package:readright/utils/firestore_utils.dart';

class AttemptModel {
  final String id;
  final String classId;
  final String userId;
  final String wordId;
  final String speechToTextTranscript;
  final AudioCodec audioCodec;
  final String audioPath;
  final int durationMS;  
  final double confidence; // 0..1 if available
  final double score; // normalized similarity 0..1
  final String devicePlatform;
  final String deviceOS;

  AttemptModel({
    String? id,
    required this.classId,
    required this.userId,
    required this.wordId,
    required this.speechToTextTranscript,
    required this.audioCodec,
    required this.audioPath,
    required this.durationMS,
    required this.confidence,
    required this.score,
    required this.devicePlatform,
    required this.deviceOS,
  }) : id = id ?? FirestoreUtils.generateDeterministicAttemptId(classId, userId, wordId, audioPath);

  // Convert AttemptModel instance to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classId': classId,
      'userId': userId,
      'wordId': wordId,
      'speechToTextTranscript': speechToTextTranscript,
      'audioCodec': audioCodec.name,
      'audioPath': audioPath,
      'durationMS': durationMS,
      'confidence': confidence,
      'score': score,
      'devicePlatform': devicePlatform,
      'deviceOS': deviceOS,
    };
  }

  // Create an AttemptModel instance from JSON data retrieved from Firestore.
  factory AttemptModel.fromJson(Map<String, dynamic> json) {
    return AttemptModel(
      id: json['id'] as String,
      classId: json['classId'] as String,
      userId: json['userId'] as String,
      wordId: json['wordId'] as String,
      speechToTextTranscript: json['speechToTextTranscript'] as String,
      audioCodec: AudioCodec.values.firstWhere(
        (e) => e.name == json['audioCodec'],
        orElse: () => AudioCodec.unknown,
      ),
      audioPath: json['audioPath'] as String,
      durationMS: json['durationMS'] as int,
      confidence: (json['confidence'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
      devicePlatform: json['devicePlatform'] as String,
      deviceOS: json['deviceOS'] as String,
    );
  }
}