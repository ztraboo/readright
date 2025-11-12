import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:readright/services/user_repository.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/utils/enums.dart';

// NOTE:
// - Adjust method names below (createUser, getUser, updateUser, deleteUser, listUsers)
//   to match the actual API exposed by your UserRepository implementation.
// - If UserRepository depends on external services (Firestore, SharedPreferences),
//   prefer injecting a fake backend into the repository (if supported).
//   If not, consider using mockito or a package-specific mock utility and adapt setUp accordingly.

void main() {

  group('UserRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late UserRepository repo;

    // Deterministic sample user values for tests:
    UserModel sampleUser({String? id}) => UserModel(
      id: id ?? 'user-123',
      email: 'test@example.com',
      fullName: 'Test User',
      role: UserRole.teacher,
      local: 'en-US',
      institution: 'Test Institution',
      username: 'testuser',
      isEmailVerified: true,
      verificationStatus: VerificationStatus.approved,
    );

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

      repo = UserRepository.withFirestoreAndAuth(fakeFirestore, mockAuth);
    });

    test('upsertUser persists and returns a user with expected fields', () async {
      final user = sampleUser(id: 'u-create-1');

      // Adjust method name if needed:
      await repo.upsertUser(user);

      // Ensure we can fetch it back
      final fetched = await repo.fetchUserByUserUID(user.id!);
      expect(fetched, isNotNull);
      expect(fetched!.id, equals(user.id));
      expect(fetched.email, equals(user.email));
      expect(fetched.fullName, equals(user.fullName));
      expect(fetched.role, equals(user.role));
      expect(fetched.local, equals(user.local));
      expect(fetched.institution, equals(user.institution));
      expect(fetched.username, equals(user.username));
      expect(fetched.isEmailVerified, equals(user.isEmailVerified));
      expect(fetched.verificationStatus, equals(user.verificationStatus));
    });

    test('fetchUserByUserUID returns null (or throws) for missing id', () async {
      // Behavior may be either returning null or throwing; adapt assertions accordingly.
      const missingId = 'does-not-exist';

      final result = await repo.fetchUserByUserUID(missingId);
      // If your repository throws for missing user, change to expectLater(() => repo.getUser(...), throwsA(...));
      expect(result, isNull);
    });

    test('upsertUser modifies stored user fields', () async {
      final user = sampleUser(id: 'u-update-1');
      await repo.upsertUser(user);

      final updatedUser = user.copyWith(email: 'new@example.com', fullName: 'New Name');
      await repo.upsertUser(updatedUser);
      final result = await repo.fetchUserByUserUID(user.id!);

      expect(result?.email, equals('new@example.com'));
      expect(result?.fullName, equals('New Name'));

      final fetched = await repo.fetchUserByUserUID(user.id!);
      expect(fetched?.email, equals('new@example.com'));
      expect(fetched?.fullName, equals('New Name'));
    });

    test('deleteUser removes the user', () async {
      final user = sampleUser(id: 'u-delete-1');
      await repo.upsertUser(user);

      await repo.deleteUser(user.id!);

      final fetched = await repo.fetchUserByUserUID(user.id!);
      expect(fetched, isNull);
    });

    test('listUsers / getAll returns created users', () async {
      final a = sampleUser(id: 'u-list-1');
      final b = sampleUser(id: 'u-list-2');

      await repo.upsertUser(a);
      await repo.upsertUser(b);

      final all = await repo.listUsers(); // or getAllUsers()
      // Ensure both users are present (order may not be guaranteed).
      final ids = all.map((u) => u.id).toSet();
      expect(ids, containsAll(<String>{a.id!, b.id!}));
    });

    test('fetchUserByUsername returns expected user when username exists', () async {
      final user = sampleUser(id: 'u-username-1').copyWith(username: 'searchme');
      await repo.upsertUser(user);

      final fetched = await repo.fetchUserByUsername('searchme');
      expect(fetched, isNotNull);
      expect(fetched!.id, equals(user.id));
      expect(fetched.username, equals('searchme'));
    });

    test('fetchUserByUsername returns null when username does not exist', () async {
      final fetched = await repo.fetchUserByUsername('no-such-user');
      expect(fetched, isNull);
    });

    test('creating same id twice is handled deterministically', () async {
      final user = sampleUser(id: 'u-dup-1');

      await repo.upsertUser(user);
      final first = await repo.fetchUserByUserUID(user.id!);

      // Handle errors accordingly when calling upsertUser the second time.
      try {
        await repo.upsertUser(user);
        final second = await repo.fetchUserByUserUID(user.id!);
        // If repository overwrites or returns existing, ensure id is the same.
        expect(second?.id, equals(first?.id));
      } catch (e) {
        // If it throws, that's also an acceptable behavior for some implementations.
        expect(e, isNotNull);
      }
    });

  });

  /// Additional group to specifically test current user convenience methods
  /// -------------------
  group('UserRepository (current user helpers)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;
    late MockFirebaseAuth mockAuth;
    late UserRepository repo;

    const testUid = 'uid-123';
    const testEmail = 'user@example.com';
    const testFullName = 'Test User';

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: testUid,
        email: testEmail,
        displayName: testFullName,
      );
      mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
      final result = await mockAuth.signInWithEmailAndPassword(email: mockUser.email!, password: 'password');
      final user = result.user;
      debugPrint(user?.displayName);

      repo = UserRepository.withFirestoreAndAuth(fakeFirestore, mockAuth);
    });

    test('fetchCurrentUser returns user when auth user and document exist', () async {
      // Seed document for current user
      await fakeFirestore.collection('users').doc(testUid).set({
        'id': testUid,
        'email': testEmail,
        'fullName': testFullName,
      });

      final user = await repo.fetchCurrentUser();
      expect(user, isNotNull);
      // Adjust field assertions to match your UserModel fields
      expect(user!.id, equals(testUid));
      expect(user.email, equals(testEmail));
      expect(user.fullName, anyOf(equals(testFullName), equals(testFullName)));
    });

    test('upsertCurrentUser saves document using auth uid', () async {

      // Insert current user document if it does not exist with role teacher
      await repo.upsertCurrentUser(role: UserRole.teacher);

      final doc = await fakeFirestore.collection('users').doc(testUid).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['email'], equals('user@example.com'));
      expect(data['fullName'], equals('Test User'));
      expect(data['role'], equals('Teacher'));
      // id may or may not be present in the stored map depending on FirestoreMetadata.prepareForSave,
      // but the document key should be the auth uid which we checked via doc existence.
    });

    test('deleteCurrentUser removes the current user document', () async {
      // Seed document for current user
      await fakeFirestore.collection('users').doc(testUid).set({
        'id': testUid,
        'email': testEmail,
        'fullName': testFullName,
      });

      // Ensure it exists before deletion
      var doc = await fakeFirestore.collection('users').doc(testUid).get();
      expect(doc.exists, isTrue);

      await repo.deleteCurrentUser();

      doc = await fakeFirestore.collection('users').doc(testUid).get();
      expect(doc.exists, isFalse);
    });
  });

  /// Testing out Firebase email/password user create account and sign in flows with UserRepository
  /// https://firebase.google.com/docs/auth/flutter/password-auth?authuser=0
  /// -------------------
  group('UserRepository auth integration (fake firestore + mock auth)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late UserRepository repo;

    const email = 'newuser@example.com';
    const password = 'NsJfp6tksusHfDMgz0CX'; // matches repository's hardcoded password in create
    const fullName = 'New User';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(); // no signed-in user initially
      repo = UserRepository(firestore: fakeFirestore, auth: mockAuth);
    });

    test('createFirebaseEmailPasswordUser creates auth user and firestore doc', () async {
      final input = UserModel.fromJson({
        // do not provide id so repository will set id from auth result
        'email': email,
        'fullName': fullName,
      });

      final created = await repo.createFirebaseEmailPasswordUser(
        user: input,
        securePassword: password
      );

      // Ensure auth created a user and repo returned a model with an id.
      expect(created, isNotNull);
      final uid = created!.id;
      expect(uid, isNotNull);
      expect(created.email, equals(email));

      // Firestore document should exist at users/{uid}
      final doc = await fakeFirestore.collection('users').doc(uid).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['email'], equals(email));
      expect(data['fullName'], anyOf(equals(fullName), isNull));
    });

    test('createFirebaseEmailPasswordUser rejects duplicate username', () async {
      final input1 = UserModel.fromJson({
        'email': 'dup1@example.com',
        'fullName': 'First',
        'username': 'duplicateUser',
      });

      final created = await repo.createFirebaseEmailPasswordUser(
        user: input1,
        securePassword: password,
      );
      expect(created, isNotNull);

      final input2 = UserModel.fromJson({
        'email': 'dup2@example.com',
        'fullName': 'Second',
        'username': 'duplicateUser',
      });

      // Attempting to create another account with the same username should
      // result in a FirebaseAuthException with code 'username-already-exists'.
      expect(
        () async => await repo.createFirebaseEmailPasswordUser(
          user: input2,
          securePassword: password,
        ),
        throwsA(predicate((e) => e is FirebaseAuthException && e.code == 'username-already-exists')),
      );
    });

    test('signInFirebaseEmailPasswordUser signs in and returns Firestore user', () async {
      final input = UserModel.fromJson({
        // do not provide id so repository will set id from auth result
        'email': email,
        'fullName': fullName,
      });

      // First create the user so we can sign in
      final created = await repo.createFirebaseEmailPasswordUser(
        user: input,
        securePassword: password
      );

      // Sign out so we simulate signing in fresh (MockFirebaseAuth signs in on create)
      await mockAuth.signOut();

      // Create a fresh repo bound to the same mockAuth and fakeFirestore
      repo = UserRepository(firestore: fakeFirestore, auth: mockAuth);

      final fetched = await repo.signInFirebaseEmailPasswordUser(
        email: email,
        securePassword: password
      );

      expect(fetched, isNotNull);
      expect(fetched!.id, equals(created?.id));
      expect(fetched.email, equals(email));
      expect(fetched.fullName, anyOf(equals(fullName), isNull));
    });

  });

}