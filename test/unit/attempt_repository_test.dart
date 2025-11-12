import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/services/attempt_repository.dart';
import 'package:readright/utils/enums.dart';

void main() {
  group('AttemptRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late AttemptRepository repo;

    setUp(() async {
      // Mock logged-in user for tests.
      mockUser = MockUser(
        isAnonymous: false,
        uid: 'user-123',
        email: 'user@example.com',
        displayName: 'Example User',
      );
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      final result = await mockAuth.signInWithEmailAndPassword(email: mockUser.email!,
          password: 'password');
      final user = result.user;
      debugPrint(user?.displayName);
      repo = AttemptRepository.withFirestoreAndAuth(fakeFirestore, mockAuth);
    });

    test('fetchAttemptsByUser returns correct attempts', () async {
      final attempt1 = AttemptModel(
        classId: 'class1',
        userId: 'user-123',
        wordId: 'word1',
        speechToTextTranscript: 'transcript one',
        audioCodec: AudioCodec.aac,
        audioPath: '/path/to/audio1.aac',
        durationMS: 1000,
        confidence: 0.8,
        score: 0.85,
        devicePlatform: 'android',
        deviceOS: '10',
      );
      final attempt2 = AttemptModel(
        classId: 'class2',
        userId: 'user-123',
        wordId: 'word2',
        speechToTextTranscript: 'transcript two',
        audioCodec: AudioCodec.wav,
        audioPath: '/path/to/audio2.wav',
        durationMS: 1500,
        confidence: 0.9,
        score: 0.95,
        devicePlatform: 'ios',
        deviceOS: '14.4',
      );
      final attempt3 = AttemptModel(
        classId: 'class1',
        userId: 'user-456',
        wordId: 'word3',
        speechToTextTranscript: 'transcript three',
        audioCodec: AudioCodec.pcm16,
        audioPath: '/path/to/audio3.pcm',
        durationMS: 2000,
        confidence: 0.85,
        score: 0.9,
        devicePlatform: 'android',
        deviceOS: '9',
      );  
      await repo.upsertAttempt(attempt1);
      await repo.upsertAttempt(attempt2);
      await repo.upsertAttempt(attempt3);
      final attempts = await repo.fetchAttemptsByUser('user-123');
      expect(attempts.length, equals(2));
      final ids = attempts.map((a) => a.id).toSet();
      expect(ids.contains(attempt1.id), isTrue);
      expect(ids.contains(attempt2.id), isTrue);
      expect(ids.contains(attempt3.id), isFalse);
    });

    test('upsertAttempt updates existing document with new values', () async {
      final original = AttemptModel(
        classId: 'upsertClass',
        userId: 'user-123',
        wordId: 'upsertWord',
        speechToTextTranscript: 'original transcript',
        audioCodec: AudioCodec.wav,
        audioPath: '/audio/original.wav',
        durationMS: 800,
        confidence: 0.6,
        score: 0.4,
        devicePlatform: 'ios',
        deviceOS: '14',
      );

      // Insert original
      await repo.upsertAttempt(original);

      // Create updated attempt with same classId/userId/wordId so id is deterministic
      final updated = AttemptModel(
        classId: 'upsertClass',
        userId: 'user-123',
        wordId: 'upsertWord',
        speechToTextTranscript: 'updated transcript',
        audioCodec: AudioCodec.wav,
        audioPath: '/audio/updated.wav',
        durationMS: 900,
        confidence: 0.95,
        score: 0.99,
        devicePlatform: 'ios',
        deviceOS: '15',
      );

      await repo.upsertAttempt(updated);

      final doc = await fakeFirestore.collection('attempts').doc(updated.id).get();
      expect(doc.exists, isTrue);

      final data = doc.data()!;
      // Updated fields should reflect the latest attempt
      expect(data['speechToTextTranscript'], equals('updated transcript'));
      expect(data['audioPath'], equals('/audio/updated.wav'));
      expect(data['durationMS'], equals(900));
      expect((data['confidence'] as num).toDouble(), equals(0.95));
      expect((data['score'] as num).toDouble(), equals(0.99));
      expect(data['deviceOS'], equals('15'));

      // Fields that remain logically the same (identifiers)
      expect(data['classId'], equals('upsertClass'));
      expect(data['wordId'], equals('upsertWord'));
      expect(data['userId'], equals('user-123'));
    });

    test('deleteAttemptById removes document', () async {
      final attempt = AttemptModel(
      classId: 'deleteClass',
      userId: 'user-123',
      wordId: 'deleteWord',
      speechToTextTranscript: 'to be deleted',
      audioCodec: AudioCodec.aac,
      audioPath: '/audio/delete.aac',
      durationMS: 500,
      confidence: 0.5,
      score: 0.5,
      devicePlatform: 'android',
      deviceOS: '11',
      );

      await repo.upsertAttempt(attempt);
      var doc = await fakeFirestore.collection('attempts').doc(attempt.id).get();
      expect(doc.exists, isTrue);

      await repo.deleteAttemptById(attempt.id);

      doc = await fakeFirestore.collection('attempts').doc(attempt.id).get();
      expect(doc.exists, isFalse);
    });

    test('deleteAttemptById on non-existent id does not throw and leaves others intact', () async {
      final a1 = AttemptModel(
      classId: 'c1',
      userId: 'user-123',
      wordId: 'w1',
      speechToTextTranscript: 'one',
      audioCodec: AudioCodec.wav,
      audioPath: '/a/1.wav',
      durationMS: 100,
      confidence: 0.1,
      score: 0.1,
      devicePlatform: 'ios',
      deviceOS: '14',
      );
      final a2 = AttemptModel(
      classId: 'c2',
      userId: 'user-123',
      wordId: 'w2',
      speechToTextTranscript: 'two',
      audioCodec: AudioCodec.wav,
      audioPath: '/a/2.wav',
      durationMS: 200,
      confidence: 0.2,
      score: 0.2,
      devicePlatform: 'ios',
      deviceOS: '14',
      );

      await repo.upsertAttempt(a1);
      await repo.upsertAttempt(a2);

      // Should not throw
      await repo.deleteAttemptById('non-existent-id-xyz');

      final snap = await fakeFirestore.collection('attempts').get();
      final ids = snap.docs.map((d) => d.id).toSet();
      expect(ids.contains(a1.id), isTrue);
      expect(ids.contains(a2.id), isTrue);
      expect(snap.docs.length, equals(2));
    });
  });
}