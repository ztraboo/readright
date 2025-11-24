import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/student_progress_model.dart';
import 'package:readright/utils/app_scoring.dart';

void main() {
  group('StudentProgressModel', () {
    test('toJson contains expected keys and fromJson preserves wordCompletedIds when provided', () {
      final model = StudentProgressModel(
        averageWordAttemptScore: 75.5,
        wordAttemptIds: ['a1', 'a2'],
        wordStruggledIds: ['w2'],
        countWordsAttempted: 2,
        uid: 'uid1',
        wordCompletedIds: ['w1'],
      );

      final json = model.toJson();

      // toJson should include numeric/count fields
      expect(json['averageWordAttemptScore'], 75.5);
      expect(json['countWordsAttempted'], 2);
      expect(json['wordAttemptIds'], isA<List<dynamic>>());
      expect(json['countWordsCompleted'], model.countWordsCompleted);

      // fromJson will reconstruct the completed set if the 'wordCompletedIds' key is present.
      json['wordCompletedIds'] = ['w1'];
      final reconstructed = StudentProgressModel.fromJson(json as Map<String, dynamic>);

      expect(reconstructed.averageWordAttemptScore, model.averageWordAttemptScore);
      expect(reconstructed.wordAttemptIds, model.wordAttemptIds);
      expect(reconstructed.countWordsAttempted, model.countWordsAttempted);
      expect(reconstructed.uid, model.uid);
      expect(reconstructed.countWordsCompleted, 1);
      expect(reconstructed.wordsCompleted, contains('w1'));
    });

    test('addAttemptId appends attempt id, increments countWordsAttempted and updates completed set when wordId provided with passing score', () {
      final base = StudentProgressModel(uid: 'student1');

      // Provide a passing score so the model will mark the word completed
      final updated = base.addAttemptId(
        'attempt-123',
        wordId: 'word-xyz',
        score: AppScoring.passingThreshold,
      );

      // original unchanged
      expect(base.wordAttemptIds, isEmpty);
      expect(base.countWordsAttempted, 0);

      // updated has new attempt
      expect(updated.wordAttemptIds, contains('attempt-123'));
      expect(updated.countWordsAttempted, base.countWordsAttempted + 1);

      // completed set updated because score meets passing threshold
      expect(updated.countWordsCompleted, 1);
      expect(updated.wordsCompleted, contains('word-xyz'));
    });

    test('addAttemptId with non-passing score records attempt and updates struggled list (does not complete)', () {
      final base = StudentProgressModel(uid: 'student3');

      // Use a score below passing threshold
      final failingScore = AppScoring.passingThreshold - 0.2;
      final updated = base.addAttemptId(
        'attempt-456',
        wordId: 'word-abc',
        score: failingScore,
      );

      // original unchanged
      expect(base.wordAttemptIds, isEmpty);
      expect(base.countWordsAttempted, 0);

      // updated has new attempt and incremented attempt count
      expect(updated.wordAttemptIds, contains('attempt-456'));
      expect(updated.countWordsAttempted, base.countWordsAttempted + 1);

      // Because the score is below threshold, the word should NOT be marked completed
      expect(updated.countWordsCompleted, 0);
      expect(updated.wordsCompleted, isNot(contains('word-abc')));

      // Instead, the word should be added to the struggled list
      expect(updated.wordStruggledIds, contains('word-abc'));
    });
  });
}