import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/utils/enums.dart';
import 'package:readright/utils/firestore_utils.dart';

void main() {
  group('AttemptModel', () {
    test('constructor generates deterministic id from classId+userId+wordId', () {
      final m = AttemptModel(
        classId: 'class123',
        userId: 'user456',
        wordId: 'attempt',
        speechToTextTranscript: 'test transcript attempt',
        audioCodec: AudioCodec.aac,
        audioPath: '/path/to/user456_attempt_1234567890.aac',
        durationMS: 1500,
        confidence: 0.85,
        score: 0.9,
        devicePlatform: 'Android',
        deviceOS: '11',
      );

      final expected = FirestoreUtils.generateDeterministicAttemptId('class123', 'user456', 'attempt', '/path/to/user456_attempt_1234567890.aac');
      expect(m.id, equals(expected));
    });

    test('toJson and fromJson roundtrip', () {
      final original = AttemptModel(
        classId: 'classABC',
        userId: 'userDEF',
        wordId: 'make',
        speechToTextTranscript: 'another transcript make',
        audioCodec: AudioCodec.wav,
        audioPath: '/path/to/userDEF_make_1234567890.wav',
        durationMS: 2000,
        confidence: 0.95,
        score: 0.98,
        devicePlatform: 'iOS',
        deviceOS: 'Version 18.6 (Build 22G86)',
      );

      final json = original.toJson();
      final fromJson = AttemptModel.fromJson(json);

      expect(fromJson.id, equals(original.id));
      expect(fromJson.classId, equals(original.classId));
      expect(fromJson.userId, equals(original.userId));
      expect(fromJson.wordId, equals(original.wordId));
      expect(fromJson.speechToTextTranscript, equals(original.speechToTextTranscript));
      expect(fromJson.audioCodec, equals(original.audioCodec));
      expect(fromJson.audioPath, equals(original.audioPath));
      expect(fromJson.durationMS, equals(original.durationMS));
      expect(fromJson.confidence, equals(original.confidence));
      expect(fromJson.score, equals(original.score));
      expect(fromJson.devicePlatform, equals(original.devicePlatform));
      expect(fromJson.deviceOS, equals(original.deviceOS));
    });
  });
}