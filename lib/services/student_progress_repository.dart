import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:readright/models/student_progress_model.dart';
import 'package:readright/utils/firestore_metadata.dart';

/// Repository for managing student progress stored in Firestore.
/// Collection: 'student.progress'
class StudentProgressRepository {
  StudentProgressRepository._internal({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  factory StudentProgressRepository({FirebaseFirestore? firestore, FirebaseAuth? auth}) =>
      StudentProgressRepository._internal(firestore: firestore, auth: auth);

  StudentProgressRepository.withFirestoreAndAuth(FirebaseFirestore firestore, FirebaseAuth auth)
      : _db = firestore,
        _auth = auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _collection => 'student.progress';

  /// Fetch a StudentProgressModel by the student's uid (document id)
  Future<StudentProgressModel?> fetchProgressByUid(String uid) async {
    final doc = await _db.collection(_collection).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return StudentProgressModel.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  /// Upsert (create or update) the provided [progress] model into Firestore.
  Future<void> upsertProgress(StudentProgressModel progress) async {
    final docRef = _db.collection(_collection).doc(progress.uid);
    final snapshot = await docRef.get();

    // Build data from model and prepare metadata.
    final data = Map<String, dynamic>.from(progress.toJson());
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
      debugPrint('Firestore upsertProgress failed: ${e.code} — ${e.message}\n$st');
      rethrow;
    }
  }

  /// Delete the progress document for a student.
  Future<void> deleteProgress(String uid) async {
    try {
      await _db.collection(_collection).doc(uid).delete();
    } on FirebaseException catch (e, st) {
      debugPrint('Firestore deleteProgress failed: ${e.code} — ${e.message}\n$st');
      rethrow;
    }
  }

  /// Register a new student under a teacher's class.
  /// This creates a new Firebase Auth user for the student,
  /// adds them to the teacher's class, and creates the initial
  /// student progress document.
  static Future<void> registerStudentByTeacherId({
    required String username,
    required String email,
    required String fullName,
    required String teacherUid,
  }) async {
    final db = FirebaseFirestore.instance;

    //Get teacher's user info
    final teacherDoc = await db.collection('users').doc(teacherUid).get();
    if (!teacherDoc.exists) throw Exception("Teacher not found");

    final teacherData = teacherDoc.data()!;
    // Store teacher institution
    final teacherInstitution = teacherData['institution'] ?? 'Unknown';

    // Find the teacher's class
    final classQuery = await db
        .collection('classes')
        .where('teacherId', isEqualTo: teacherUid)
        .limit(1)
        .get();

    // Ensure the teacher has an existing class
    if (classQuery.docs.isEmpty)
      throw Exception("No class found for this teacher");

    final classData = classQuery.docs.first.data();
    final classId = classQuery.docs.first.id;

    // Use the class code as student's password
    final classCode = classData['classCode'];

    // Create a temporary secondary Firebase app instance so the teacher stays signed in
    final secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp-${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    // Create student account using the secondary auth instance
    final userCred = await FirebaseAuth.instanceFor(
      app: secondaryApp,
    ).createUserWithEmailAndPassword(email: email, password: classCode);

    final uid = userCred.user!.uid;

    // Add student to users
    await db.collection('users').doc(uid).set({
      'id': uid,
      'email': email,
      'username': username,
      'fullName': fullName,
      'role': 'student',
      // Set student instituion to teacher's
      'institution': teacherInstitution,
      'isEmailVerified': true,
      'verificationStatus': 'approved',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add student to class
    await db.collection('classes').doc(classId).update({
      'studentIds': FieldValue.arrayUnion([uid]),
    });

    // Create the student details
    await createInitialProgressDocument(
      db: db,
      uid: uid,
      classId: classId,
    );
    
    // Sign out the student from the secondary auth instance
    await FirebaseAuth.instanceFor(app: secondaryApp).signOut();

    // Remove the temporary Firebase app
    await secondaryApp.delete();
  }

  /// Create the initial student progress document in the provided Firestore
  /// instance. This is split out so it can be tested independently of
  /// Firebase app / auth initialization used in `registerStudentByTeacherId`.
  static Future<void> createInitialProgressDocument({
    required FirebaseFirestore db,
    required String uid,
    required String classId,
  }) async {
    await db.collection('student.progress').doc(uid).set({
      'uid': uid,
      'class': classId,
      'averageWordAttemptScore': 0,
      'countWordsCompleted': 0,
      'countWordsAttempted': 0,
      'wordAttemptIds': <String>[],
      'wordCompletedIds': <String>[],
      'wordStruggledIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}