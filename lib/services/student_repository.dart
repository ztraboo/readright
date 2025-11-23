import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class StudentRepository {
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
    await db.collection('student.progress').doc(uid).set({
      'uid': uid,
      'class': classId,
      'attempts': [],
      'averageScore': 0,
      'completed': 0,
      'topStruggled': [],
      'totalAttempts': 0,
    });
    
    // Sign out the student from the secondary auth instance
    await FirebaseAuth.instanceFor(app: secondaryApp).signOut();

    // Remove the temporary Firebase app
    await secondaryApp.delete();
  }
}
