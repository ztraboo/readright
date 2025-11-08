import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/utils/enums.dart';
import 'package:readright/utils/firestore_metadata.dart';

/// Repository for managing word data in Firestore
/// Handles CRUD operations for WordModel instances.
/// 
/// Collection: 'words'
/// 
/// createdAt: timestamp, servertimestamp when the document was created.
/// createdBy: string, Firebase authentication account User UID
/// id: string, deterministic SHA-256 based on (namespace, word text, and word category) - unique across multiple devices.
/// level: string, category of word (e.g. "Sight Words, Phonics Pattern")
/// sentences: array of strings, word used in different sentences.
/// text: string, the word itself.
/// updatedAt: timestamp, servertimestamp when the document was updated.

class WordRepository {
  // Singleton pattern so we don’t open multiple DB connections accidentally. 
  WordRepository._internal({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Factory constructor for WordRepository allowing optional injection
  // of FirebaseFirestore and FirebaseAuth instances for testing.
  factory WordRepository({FirebaseFirestore? firestore, FirebaseAuth? auth}) =>
      WordRepository._internal(firestore: firestore, auth: auth);

  /// Create a testable instance backed by an injected [FirebaseFirestore].
  /// Use this in unit tests with a mock Firestore and Auth implementation.
  WordRepository.withFirestoreAndAuth(FirebaseFirestore firestore, FirebaseAuth auth)
    : _db = firestore, _auth = auth;

  // Initialize instance of Cloud Firestore
  final FirebaseFirestore _db;
  final FirebaseAuth _auth; 


  // Fetch a word by its ID from Firestore
  Future<WordModel?> fetchWordById(String id) async {
    final doc = await _db.collection('words').doc(id).get();
    if (doc.exists) {
      return WordModel.fromJson(doc.data()!);
    }
    return null;
  } 

  // Fetch level words from Firestore ordered by levelOrder ascending.
  Future<List<WordModel>> fetchLevelWords(WordLevel level) async {
    final querySnapshot = await _db.collection('words')
      .where('level', isEqualTo: level.name)
      .orderBy('levelOrder', descending: false)
      .get();
    return querySnapshot.docs
      .map((doc) => WordModel.fromJson(doc.data()))
      .toList();
  } 

  // Set or update a word in Firestore
  Future<void> upsertWord(WordModel word) async {
    final docRef = _db.collection('words').doc(word.id);
    final snapshot = await docRef.get();
    final data = Map<String, dynamic>.from(word.toJson());

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

  // Add a word letting Firestore auto-generate the document ID. After the
  // document is created, write the generated id back into the document's
  // `id` field so documents also contain their logical id.
  Future<String> addWordAutoId(WordModel word) async {
    final data = Map<String, dynamic>.from(word.toJson());
    // Remove any existing id so Firestore generates one for us.
    data.remove('id');
    final prepared = FirestoreMetadata.prepareForSave(
      data,
      isNew: true,
      uid: _auth.currentUser?.uid,
    );

    try {
      final docRef = await _db.collection('words').add(prepared);
      // Optionally write the generated id into the document for easier queries.
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } on FirebaseException catch (e, st) {
      // Handle Firestore-specific errors
      debugPrint("Firestore addWordAutoId failed: ${e.code} — ${e.message}\n$st");
      rethrow;
    }
  
  }

  // Delete a word from Firestore by its ID
  Future<void> deleteWord(String id) async {
    try {
      await _db.collection('words').doc(id).delete();
    } on FirebaseException catch (e, st) {
      // Handle Firestore-specific errors
      debugPrint("Firestore delete failed: ${e.code} — ${e.message}\n$st");
    }
  }

}