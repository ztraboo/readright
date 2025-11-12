import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/utils/enums.dart';
import 'package:readright/utils/firestore_utils.dart';

void main() {
  group('WordModel', () {
    test('constructor generates deterministic id from text+level', () {
      final m = WordModel(
        text: 'away',
        level: WordLevel.prePrimer,
        levelOrder: 3,
        sentences: [],
      );

      final expected = FirestoreUtils.generateDeterministicWordId('away', WordLevel.prePrimer.name);
      expect(m.id, equals(expected));
    });

    test('same text+level produce same id', () {
      final a = WordModel(text: 'blue', level: WordLevel.prePrimer, levelOrder: 5, sentences: []);
      final b = WordModel(text: 'blue', level: WordLevel.prePrimer, levelOrder: 5, sentences: []);
      expect(a.id, equals(b.id));
    });

    test('different level produce different ids', () {
      final a = WordModel(text: 'will', level: WordLevel.primer, levelOrder: 50, sentences: []);
      final b = WordModel(text: 'again', level: WordLevel.firstGrade, levelOrder: 2, sentences: []);
      expect(a.id, isNot(equals(b.id)));
    });

    test('fromJson uses provided id', () {
      final json = {
        'id': 'provided-id',
        'text': 'could',
        'level': WordLevel.firstGrade.name,
        'levelOrder': 8,
        'sentences': <String>[],
      };
      final m = WordModel.fromJson(json);
      expect(m.id, equals('provided-id'));
    });

    test('fromJson generates deterministic id when missing', () {
      final json = {
        'text': 'every',
        'level': WordLevel.firstGrade.name,
        'levelOrder': 9,
        'sentences': <String>[],
      };
      final m = WordModel.fromJson(json);
      final expected = FirestoreUtils.generateDeterministicWordId('every', WordLevel.firstGrade.name);
      expect(m.id, equals(expected));
    });

    test('toJson roundtrip and copyWith', () {
      final original = WordModel(text: 'want', level: WordLevel.primer, levelOrder: 43, sentences: ['I want a cookie for dessert.','Do you want to play a game?','They want to go swimming today.']);
      final json = original.toJson();
      final fromJson = WordModel.fromJson(json);

      expect(fromJson.text, equals(original.text));
      expect(fromJson.level, equals(original.level));
      expect(fromJson.levelOrder, equals(original.levelOrder));
      expect(fromJson.sentences, equals(original.sentences));

      final modified = original.copyWith(text: 'wanty');
      expect(modified.id, isNot(equals(original.id)));
      expect(modified.text, equals('wanty'));
    });
  });
}
