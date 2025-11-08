import 'package:flutter_test/flutter_test.dart';
import 'package:readright/utils/seed_words_uploader.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/utils/enums.dart';

void main() {
  group('SeedWordsUploader', () {
    test('uploadFromString parses CSV and calls upsert for each word', () async {
      final csv = '''Word,Category,LevelOrder,Sentence 1,Sentence 2
away,Dolch Pre-Primer,3,"Please go away","Don't go"
blue,Dolch Pre-Primer,5,"Sky is blue","Blue hat"
''';
      final saved = <WordModel>[];
      await SeedWordsUploader.uploadFromString(csv, upsertFn: (w) async {
        saved.add(w);
      });

      expect(saved.length, equals(2));
      expect(saved[0].text, equals('away'));
      expect(saved[0].sentences.length, equals(2));
      expect(saved[0].level, equals(WordLevel.prePrimer));

      expect(saved[1].text, equals('blue'));
      expect(saved[1].sentences.length, equals(2));
    });

    test('onProgress is called with correct counts', () async {
      final csv = '''Word,Category
one,Dolch Pre-Primer
two,Dolch Pre-Primer
three,Dolch Pre-Primer
''';
      final calls = <int>[];
      await SeedWordsUploader.uploadFromString(csv, upsertFn: (w) async {}, onProgress: (i, total) {
        calls.add(i);
        expect(total, equals(3));
      });
      expect(calls, equals([1, 2, 3]));
    });
  });
}
