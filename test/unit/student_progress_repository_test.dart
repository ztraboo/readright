import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:readright/models/student_progress_model.dart';
import 'package:readright/services/student_progress_repository.dart';

void main() {
  group('StudentProgressRepository (unit)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late StudentProgressRepository repo;
    late String testUid;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      // Provide a signed-in mock user so prepareForSave can pick up uid if needed.
      final mockUser = MockUser(uid: 'student-uid-1', email: 'student@example.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      testUid = mockUser.uid; // use this stable uid in tests
      // Create repository instance that uses injected firestore & auth via the named constructor.
      repo = StudentProgressRepository.withFirestoreAndAuth(fakeFirestore, mockAuth);
    });

    test('fetchProgressByUid returns null when missing', () async {
      final got = await repo.fetchProgressByUid('missing-uid');
      expect(got, isNull);
    });

    test('upsertProgress creates document and fetchProgressByUid returns model', () async {
      final model = StudentProgressModel(
        averageWordAttemptScore: 0.0,
        wordAttemptIds: const <String>[],
        wordStruggledIds: const <String>[],
        countWordsAttempted: 0,
        uid: testUid,
        wordCompletedIds: const <String>[],
      );

      // Upsert the model
      await repo.upsertProgress(model);

      // Directly read the document from the fake firestore to verify persisted fields
      final doc = await fakeFirestore.collection('student.progress').doc(model.uid).get();
      expect(doc.exists, isTrue);

      final data = doc.data()!;
      expect(data['uid'], model.uid);
      expect(data['wordAttemptIds'], isA<List<dynamic>>());
      expect(data['averageWordAttemptScore'], equals(model.averageWordAttemptScore));

      // Now use repository fetch to get a deserialized model
      final fetched = await repo.fetchProgressByUid(model.uid);
      expect(fetched, isNotNull);
      expect(fetched!.uid, model.uid);
      expect(fetched.countWordsAttempted, model.countWordsAttempted);
    });

    test('upsertProgress then deleteProgress removes document', () async {
      final uid = testUid;
      final model = StudentProgressModel(uid: uid);

      await repo.upsertProgress(model);

      var doc = await fakeFirestore.collection('student.progress').doc(uid).get();
      expect(doc.exists, isTrue);

      await repo.deleteProgress(uid);

      doc = await fakeFirestore.collection('student.progress').doc(uid).get();
      expect(doc.exists, isFalse);
    });
  });

  group('StudentProgressRepository createInitialProgressDocument', () {
    test('writes initial progress doc with expected fields', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final uid = 'test-student-uid';
      final classId = 'class-123';

      await StudentProgressRepository.createInitialProgressDocument(
        db: fakeFirestore,
        uid: uid,
        classId: classId,
      );

      final doc = await fakeFirestore.collection('student.progress').doc(uid).get();
      expect(doc.exists, isTrue);

      final data = doc.data()!;
      expect(data['uid'], uid);
      expect(data['class'], classId);
      expect(data['averageWordAttemptScore'], 0);
      expect(data['countWordsCompleted'], 0);
      expect(data['countWordsAttempted'], 0);
      expect(data['wordAttemptIds'], isA<List<dynamic>>());
      expect(data['wordCompletedIds'], isA<List<dynamic>>());
      expect(data['wordStruggledIds'], isA<List<dynamic>>());
      // createdAt/updatedAt are FieldValue.serverTimestamp() placeholders in the set call,
      // FakeFirebaseFirestore keeps them as a sentinel; ensure key exists
      expect(data.containsKey('createdAt'), isTrue);
      expect(data.containsKey('updatedAt'), isTrue);
    });
  });
}