import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/utils/enums.dart';
import 'package:readright/utils/firestore_metadata.dart';

/// Repository for managing user data in Firestore
/// Handles CRUD operations for UserModel instances.
/// 
/// Collection: 'users'
///   
/// createdAt: timestamp, servertimestamp when the document was created.
/// createdBy: string, Firebase authentication account User UID
/// email: string, user's email address.
/// fullName: string, user's full name.
/// id: string, Firebase authentication account User UID
/// isEmailVerified: boolean, whether the user's email has been verified.
/// local: string, user's locale (e.g. "en-US").
/// role: string, user's role (e.g. "student", "teacher").
/// updatedAt: timestamp, servertimestamp when the document was updated.
/// verificationStatus: string, user's verification status (e.g. "unknown", "pending", "verified", "rejected").
class UserRepository {
  // Singleton pattern so we don’t open multiple DB connections accidentally. 
  UserRepository._internal({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Factory constructor for UserRepository allowing optional injection
  // of FirebaseFirestore and FirebaseAuth instances for testing.
  factory UserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth}) =>
      UserRepository._internal(firestore: firestore, auth: auth);

  /// Create a testable instance backed by an injected [FirebaseFirestore].
  /// Use this in unit tests with a mock Firestore and Auth implementation.
  UserRepository.withFirestoreAndAuth(FirebaseFirestore firestore, FirebaseAuth auth)
    : _db = firestore, _auth = auth;

  // Initialize instance of Cloud Firestore
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Fetch a user by their User UID from Firestore
  Future<UserModel?> fetchUserByUserUID(String userUID) async {
    final doc = await _db.collection('users').doc(userUID).get();
    if (doc.exists) {
      return UserModel.fromJson(doc.data()!);   
    }
    return null;
  }

  // Fetch all users from Firestore
  Future<List<UserModel>> listUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
  }

  // Set or update a user in Firestore
  Future<void> upsertUser(UserModel user) async {
    final docRef = _db.collection('users').doc(user.id);
    final snapshot = await docRef.get();
    final data = Map<String, dynamic>.from(user.toJson());

    final prepared = FirestoreMetadata.prepareForSave(
      data,
      isNew: !snapshot.exists,
      // provide uid when available; helper will also attempt FirebaseAuth (_auth.instance)
      uid: _auth.currentUser?.uid,
    );

    try {
      await docRef.set(prepared);
    } on FirebaseException catch (e, st) {
      // Handle Firestore-specific errors
      debugPrint("Firestore upsert failed: ${e.code} — ${e.message}\n$st");
    }
  }

  // Convenience: fetch the currently-signed-in user's document. Returns
  // null when no user is signed in or when the document does not exist.
  Future<UserModel?> fetchCurrentUser() async {
    final current = _auth.currentUser;
    if (current == null) return null;
    return fetchUserByUserUID(current.uid);
  }

  // Create a new FirebaseAuth user and corresponding Firestore document.
  Future<UserModel?> createFirebaseEmailPasswordUser({required UserModel user, required String securePassword}) async {
    try {
      final authResult = await _auth.createUserWithEmailAndPassword(
        email: user.email,
        password: securePassword,
      );
      // Use the UID from FirebaseAuth as the document ID in Firestore.
      final newUser = user.copyWith(id: authResult.user?.uid);
      await upsertUser(newUser);
      return newUser;
    } on FirebaseAuthException catch (e, st) {
      debugPrint("Auth fetchSignInMethodsForEmail failed: ${e.code} — ${e.message}\n$st");

      if (e.code == 'user-not-found') {
        debugPrint('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        debugPrint('Wrong password provided for that user.');
      } else if (e.code == 'email-already-in-use') {
        debugPrint('The account already exists for that email.');
      }
      rethrow;
    }
  }

  // Sign in an existing FirebaseAuth user with email and password.
  Future<UserModel?> signInFirebaseEmailPasswordUser({required String email, required String securePassword}) async {
    try {
      final authResult = await _auth.signInWithEmailAndPassword(
        email: email,
        password: securePassword,
      );
      final userUID = authResult.user?.uid;
      if (userUID != null) {
        UserModel? userModel = await fetchUserByUserUID(userUID);

        // Exit early if we found the user document
        if (userModel != null) {
          return userModel;
        }

        // Create a new users document if not found based on the logged-in auth user
        // And try to fetch the users document again.
        try {
          await upsertCurrentUser(role: UserRole.teacher);
          
          userModel = await fetchUserByUserUID(userUID);
          return userModel;
        } catch (e, st) {
          debugPrint("Error creating user document after sign-in: ${e.toString()}\n$st");
        }
      }
    } on FirebaseAuthException catch (e, st) {
      debugPrint("Auth signInWithEmailAndPassword failed: ${e.code} — ${e.message}\n$st");
    }
    return null;
  }

  // Sign out the currently-signed-in user.
  Future<void> signOutCurrentUser() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e, st) {
      debugPrint("Auth signOut failed: ${e.code} — ${e.message}\n$st");
    }
  }

  // Convenience: upsert the currently-signed-in user's document using
  // `FirebaseAuth.instance.currentUser?.uid` as the document id. If there
  // is no signed-in user this throws a [StateError].
  Future<void> upsertCurrentUser({required UserRole role}) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw StateError('No signed-in user available');
    }
    // Ensure the model uses the auth uid so the document key matches.
    final toSave = UserModel(
      id: current.uid,
      email: current.email as String,
      fullName: current.displayName ?? '',
      role: role,
      local: "en-US",
      isEmailVerified: current.emailVerified,
      verificationStatus: VerificationStatus.unknown,
    );
    //  user.copyWith(id: current.uid);
    
    debugPrint('Upserting current user with UID: ${toSave.id}');
    await upsertUser(toSave);
  }


  // Delete a user from Firestore by their User UID
  Future<void> deleteUser(String userUID) async {
    final docRef = _db.collection('users').doc(userUID);

    try {
      await docRef.delete();
    } on FirebaseException catch (e, st) {
      // Handle Firestore-specific errors
      debugPrint("Firestore delete failed: ${e.code} — ${e.message}\n$st");
    }

    // TODO: Consider cascading delete of related data if necessary.

    // For security reasons, we cannot delete a FirebaseAuth user here that is not the currentUser.
    // Deleting other users would require elevated privileges not available within the Flutter client.
    // If you need to delete the FirebaseAuth user, consider using a Cloud Console.
  
  }

  // Delete the currently-signed-in user's document. If there is no signed-in
  // user this throws a [StateError].
  Future<void> deleteCurrentUser() async {
    final current = _auth.currentUser;
    if (current == null) {
      throw StateError('No signed-in user available');
    }

    // Need to delete both the Firestore document and the FirebaseAuth user.
    await deleteUser(current.uid);
    await _auth.currentUser?.delete();
  }

}