
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:readright/models/word_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  static final WordRepository _instance = WordRepository._internal();
  factory WordRepository() => _instance;
  WordRepository._internal() : _db = FirebaseFirestore.instance;

  /// Create a testable instance backed by an injected [FirebaseFirestore].
  /// Use this in unit tests with a mock Firestore implementation.
  WordRepository.withFirestore(FirebaseFirestore firestore) : _db = firestore;

  // Initialize instance of Cloud Firestore
  final FirebaseFirestore _db;

  // Fetch a word by its ID from Firestore
  Future<WordModel?> fetchWordById(String id) async {
    final doc = await _db.collection('words').doc(id).get();
    if (doc.exists) {
      return WordModel.fromJson(doc.data()!);
    }
    return null;
  } 

  // Fetch all words from Firestore
  Future<List<WordModel>> fetchAllWords() async {
    final querySnapshot = await _db.collection('words').get();
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
      uid: FirebaseAuth.instance.currentUser?.uid,
    );

    if (!snapshot.exists) {
      await docRef.set(prepared);
    } else {
      await docRef.set(prepared, SetOptions(merge: true));
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
      uid: FirebaseAuth.instance.currentUser?.uid,
    );

    final docRef = await _db.collection('words').add(prepared);
    // Optionally write the generated id into the document for easier queries.
    await docRef.update({'id': docRef.id});
    return docRef.id;
  }

  // Delete a word from Firestore by its ID
  Future<void> deleteWord(String id) async {
    await _db.collection('words').doc(id).delete();
  }

}