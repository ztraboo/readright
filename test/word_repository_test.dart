import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/services/word_respository.dart';
import 'package:readright/utils/enums.dart';

void main() {
  group('WordsRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late WordRepository repo;

    setUp(() async {
      // Mock logged-in user for tests.
      mockUser = MockUser(
        isAnonymous: false,
        uid: 'user-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      final result = await mockAuth.signInWithEmailAndPassword(email: mockUser.email!, password: 'password');
      final user = result.user;
      debugPrint(user?.displayName);

      repo = WordRepository.withFirestoreAndAuth(fakeFirestore, mockAuth);
    });

    test('upsertWord and fetchWordById', () async {
      final word = WordModel(text: 'during', level: WordLevel.fourthGrade, levelOrder: 19, sentences: ['a']);
      await repo.upsertWord(word);

      final fetched = await repo.fetchWordById(word.id);
      expect(fetched, isNotNull);
      expect(fetched!.text, equals('during'));
    });

    test('addWordAutoId returns generated id and document contains it', () async {
      final word = WordModel(text: 'finally', level: WordLevel.fourthGrade, levelOrder: 23, sentences: []);
      final generatedId = await repo.addWordAutoId(word);

      final doc = await fakeFirestore.collection('words').doc(generatedId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['id'], equals(generatedId));
    });

    test('fetchLevelWords returns multiple entries ordered by levelOrder', () async {
      final a = WordModel(text: 'gave', level: WordLevel.secondGrade, levelOrder: 17, sentences: []);
      final b = WordModel(text: 'right', level: WordLevel.secondGrade, levelOrder: 27, sentences: []);
      final c = WordModel(text: 'always', level: WordLevel.secondGrade, levelOrder: 1, sentences: []);
      await repo.upsertWord(a);
      await repo.upsertWord(b);
      await repo.upsertWord(c);

      final all = await repo.fetchLevelWords(WordLevel.secondGrade);

      // Check words are there and in the correct order ascending by levelOrder.
      expect(all.length, equals(3));
      expect(all[0].text, equals('always'));
      expect(all[1].text, equals('gave'));
      expect(all[2].text, equals('right'));
      expect(all[0].levelOrder, lessThan(all[1].levelOrder));
      expect(all[1].levelOrder, lessThan(all[2].levelOrder));
    });

    test('deleteWord removes the document', () async {
      final w = WordModel(text: 'myself', level: WordLevel.thirdGrade, levelOrder: 26, sentences: []);
      await repo.upsertWord(w);
      await repo.deleteWord(w.id);
      final fetched = await repo.fetchWordById(w.id);
      expect(fetched, isNull);
    });
  });
}
