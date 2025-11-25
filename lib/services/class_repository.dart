import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:readright/models/class_model.dart';
import 'package:readright/utils/firestore_metadata.dart';

/// Repository for managing class data in Firestore
/// Handles CRUD operations for ClassModel instances.
///
/// Collection: 'classes'
///
/// createdAt: timestamp, servertimestamp when the document was created.
/// createdBy: string, Firebase authentication account User UID
/// id: string, document id (may be generated or provided).
/// name: string, human-friendly class name.
/// averageClassWordAttemptScore: double, average class score (0..100).
/// classCode: string, join code / passcode for the class.
/// teacherId: string, UID of the teacher who owns the class.
/// studentIds: array of student UIDs.
/// topStrugglingWords: array of words for the class.
/// totalWordsToComplete: integer, planned total words for the class.
class ClassRepository {
  // Singleton pattern so we don’t open multiple DB connections accidentally.
  ClassRepository._internal({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // Factory constructor for ClassRepository allowing optional injection
  // of FirebaseFirestore and FirebaseAuth instances for testing.
  factory ClassRepository({FirebaseFirestore? firestore, FirebaseAuth? auth}) =>
      ClassRepository._internal(firestore: firestore, auth: auth);

  /// Create a testable instance backed by an injected [FirebaseFirestore].
  /// Use this in unit tests with a mock Firestore and Auth implementation.
  ClassRepository.withFirestoreAndAuth(FirebaseFirestore firestore, FirebaseAuth auth)
      : _db = firestore,
        _auth = auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Fetch a class by its document ID from Firestore
  Future<ClassModel?> fetchClassById(String id) async {
    final doc = await _db.collection('classes').doc(id).get();
    if (doc.exists) {
      return ClassModel.fromJson(doc.data()!);
    }
    return null;
  }

  // Fetch a class by its classCode (passcode)
  Future<ClassModel?> fetchClassByCode(String classCode) async {
    final querySnapshot = await _db
        .collection('classes')
        .where('classCode', isEqualTo: classCode)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return ClassModel.fromJson(querySnapshot.docs.first.data());
    }
    return null;
  }

  // Fetch classes for a specific teacher
  Future<List<ClassModel>> fetchClassesByTeacher(String teacherId) async {
    final querySnapshot = await _db
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .get();
    return querySnapshot.docs
        .map((doc) => ClassModel.fromJson(doc.data()))
        .toList();
  }

  // Fetch classes for a specific student
  Future<List<ClassModel>> fetchClassesByStudent(String studentId) async {
    final querySnapshot = await _db
        .collection('classes')
        .where('studentIds', arrayContains: studentId)
        .get();
    return querySnapshot.docs
        .map((doc) => ClassModel.fromJson(doc.data()))
        .toList();
  }

  // Fetch students in a specific class by class ID
  Future<List<String>> fetchStudentIdsByClassId(String classId) async {
    final doc = await _db.collection('classes').doc(classId).get();
    if (doc.exists) {
      final data = doc.data()!;
      final studentIds = List<String>.from(data['studentIds'] ?? []);
      return studentIds;
    }
    return [];
  }

  // List all classes (use with care — may return many documents)
  Future<List<ClassModel>> listClasses() async {
    final snapshot = await _db.collection('classes').get();
    return snapshot.docs.map((doc) => ClassModel.fromJson(doc.data())).toList();
  }

  // Set or update a class in Firestore
  Future<void> upsertClass(ClassModel cls) async {
    final docRef = _db.collection('classes').doc(cls.id);
    final snapshot = await docRef.get();
    final data = Map<String, dynamic>.from(cls.toJson());

    final prepared = FirestoreMetadata.prepareForSave(
      data,
      isNew: !snapshot.exists,
      uid: _auth.currentUser?.uid,
    );

    try {
      if (!snapshot.exists) {
        await docRef.set(prepared);
      } else {
        await docRef.set(prepared, SetOptions(merge: true));
      }
    } on FirebaseException catch (e, st) {
      debugPrint("Firestore upsert failed: ${e.code} — ${e.message}\n$st");
    }
  }

  // Delete a class from Firestore by its ID
  Future<void> deleteClass(String id) async {
    try {
      await _db.collection('classes').doc(id).delete();
    } on FirebaseException catch (e, st) {
      debugPrint("Firestore delete failed: ${e.code} — ${e.message}\n$st");
    }
  }
}