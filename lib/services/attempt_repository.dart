import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/utils/enums.dart';
import 'package:readright/utils/firestore_metadata.dart';

/// Repository for managing attempt data in Firestore
/// Handles CRUD operations for AttemptModel instances.
/// 
/// Collection: 'attempts'
/// createdAt: timestamp, servertimestamp when the document was created.
/// createdBy: string, Firebase authentication account User UID
/// id: string, deterministic SHA-256 based on (classId, userId, wordId) - unique across multiple devices.
/// wordId: string, the ID of the word being attempted.
/// speechToTextTranscript: string, the transcript returned by the speech-to-text engine.
/// audioCodec: string, the codec used for the audio recording.
/// audioPath: string, path to the audio file in storage.
/// durationMS: integer, duration of the audio recording in milliseconds.
/// confidence: double, confidence score from the speech-to-text engine (0..1).
/// score: double, normalized similarity score (0..1).
/// deviceInfo: string, information about the device used for the attempt.
/// updatedAt: timestamp, servertimestamp when the document was updated.

class AttemptRepository {
  // Singleton pattern so we don’t open multiple DB connections accidentally. 
  AttemptRepository._internal({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Factory constructor for AttemptRepository allowing optional injection
  // of FirebaseFirestore and FirebaseAuth instances for testing.
  factory AttemptRepository({FirebaseFirestore? firestore, FirebaseAuth? auth}) =>
      AttemptRepository._internal(firestore: firestore, auth: auth);

  /// Create a testable instance backed by an injected [FirebaseFirestore].
  /// Use this in unit tests with a mock Firestore and Auth implementation.
  AttemptRepository.withFirestoreAndAuth(FirebaseFirestore firestore, FirebaseAuth auth)
    : _db = firestore, _auth = auth;

  // Initialize instance of Cloud Firestore
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Fetch attempts by userId from Firestore
  Future<List<AttemptModel>> fetchAttemptsByUser(String userId, {String? classId, String? wordId, AudioCodec? audioCodec}) async {
    Query query = _db.collection('attempts').where('userId', isEqualTo: userId);
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }
    if (wordId != null) {
      query = query.where('wordId', isEqualTo: wordId);
    }
    if (audioCodec != null) {
      query = query.where('audioCodec', isEqualTo: audioCodec.name);
    }
    final querySnapshot = await query.get();
    return querySnapshot.docs
      .map((doc) => AttemptModel.fromJson(doc.data() as Map<String, dynamic>))
      .toList();
  }

  // Set or update an attempt in Firestore
  Future<void> upsertAttempt(AttemptModel attempt) async {
    final docRef = _db.collection('attempts').doc(attempt.id);
    final snapshot = await docRef.get();
    final data = Map<String, dynamic>.from(attempt.toJson());

    final prepared = FirestoreMetadata.prepareForSave(
      data,
      isNew: !snapshot.exists,
      // provide uid when available; helper will also attempt FirebaseAuth
      uid: _auth.currentUser?.uid,
    );

    try {
      if (!snapshot.exists) {
        await docRef.set(prepared);
      } else {
        await docRef.set(prepared, SetOptions(merge: true));
      }
    } on FirebaseException catch (e, st) {
      // Handle Firestore-specific errors
      debugPrint("Firestore upsert failed: ${e.code} — ${e.message}\n$st");
    }

  } 

  // Delete an attempt by its ID from Firestore
  Future<void> deleteAttemptById(String id) async {
    final docRef = _db.collection('attempts').doc(id);
    try {
      await docRef.delete();
    } on FirebaseException catch (e, st) {
      // Handle Firestore-specific errors
      debugPrint("Firestore delete failed: ${e.code} — ${e.message}\n$st");
    }
  }

}