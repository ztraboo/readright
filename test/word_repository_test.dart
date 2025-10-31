import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/services/word_respository.dart';
import 'package:readright/utils/enums.dart';

void main() {
  group('WordsRepository', () {
    late FakeFirebaseFirestore mockFirestore;
    late WordRepository repo;

    setUp(() {
      mockFirestore = FakeFirebaseFirestore();
      repo = WordRepository.withFirestore(mockFirestore);
    });

    test('upsertWord and fetchWordById', () async {
      final word = WordModel(text: 'test', level: WordLevel.sightWord, sentences: ['a']);
      await repo.upsertWord(word);

      final fetched = await repo.fetchWordById(word.id);
      expect(fetched, isNotNull);
      expect(fetched!.text, equals('test'));
    });

    test('addWordAutoId returns generated id and document contains it', () async {
      final word = WordModel(text: 'auto', level: WordLevel.sightWord, sentences: []);
      final generatedId = await repo.addWordAutoId(word);

      final doc = await mockFirestore.collection('words').doc(generatedId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['id'], equals(generatedId));
    });

    test('fetchAllWords returns multiple entries', () async {
      final a = WordModel(text: 'a', level: WordLevel.sightWord, sentences: []);
      final b = WordModel(text: 'b', level: WordLevel.sightWord, sentences: []);
      await repo.upsertWord(a);
      await repo.upsertWord(b);

      final all = await repo.fetchAllWords();
      expect(all.length, equals(2));
      final texts = all.map((w) => w.text).toSet();
      expect(texts.contains('a'), isTrue);
      expect(texts.contains('b'), isTrue);
    });

    test('deleteWord removes the document', () async {
      final w = WordModel(text: 'del', level: WordLevel.sightWord, sentences: []);
      await repo.upsertWord(w);
      await repo.deleteWord(w.id);
      final fetched = await repo.fetchWordById(w.id);
      expect(fetched, isNull);
    });
  });
}
