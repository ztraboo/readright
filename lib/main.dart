//Test changes - Jon
import 'package:flutter/material.dart';

// Firebase packages
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// import 'package:readright/screens/teacher/teacher_word_dashboard_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/reader_selection_screen.dart';
import 'screens/student/student_login_screen.dart';
import 'screens/student/student_passcode_verification_screen.dart';
import 'screens/student/student_word_dashboard_screen.dart';
import 'screens/student/student_word_practice_screen.dart';
import 'screens/student/student_word_feedback_screen.dart';
import 'screens/teacher/login/teacher_login_screen.dart';
import 'screens/teacher/login/teacher_register_screen.dart';
import 'screens/teacher/login/teacher_password_reset_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/teacher/teacher_word_dashboard_screen.dart';
import 'screens/teacher/class/class_dashboard_screen.dart';
import 'screens/teacher/class/class_student_details_screen.dart';

// TEST USER CREATION, SIGN IN, AND DELETION
// This is commented out to avoid unused import warnings
// import 'models/user_model.dart';
// import 'services/user_repository.dart';
// import 'utils/enums.dart';
// import 'utils/seed_words_uploader.dart';

Future<void> main() async {

  // Use default Firebase options for app initialization
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // // TEST USER CREATION
  // try {
  //   final newUser = await UserRepository().createFirebaseEmailPasswordUser(
  //     user: UserModel(
  //       email: 'testing@example.com',
  //       fullName: 'Testing User',
  //       role: UserRole.teacher,
  //       local: 'en-US',
  //       isEmailVerified: false,
  //       verificationStatus: VerificationStatus.approved,
  //     ),
  //     securePassword: 'Testing@1234',
  //   );
  //   debugPrint('New user created: ${newUser?.id} ${newUser?.fullName}, ${newUser?.email}');
  // } on FirebaseException catch (e, st) {
  //   debugPrint('Error creating user: ${e.code} — ${e.message}\n$st');
  // }

  // // TEST INVALID USER SIGN IN
  // await UserRepository().signOutCurrentUser();
  // final invalidUser = await UserRepository().signInFirebaseEmailPasswordUser(
  //   email: 'invalid@example.com',
  //   securePassword: 'Invalid@1234',
  // );
  // debugPrint('Invalid user sign in attempt: ${invalidUser?.email}');

  // // TEST VALID USER SIGN IN
  // final validUser = await UserRepository().signInFirebaseEmailPasswordUser(
  //   email: 'testing@example.com',
  //   securePassword: 'Testing@1234',
  // );
  // debugPrint('Valid user sign in attempt: ${validUser?.email}');

  // // DELETE VALID USER DOCUMENT
  // if (validUser != null) {
  //   await UserRepository().deleteUser(validUser.id as String);
  //   debugPrint('Deleted user document for ${validUser.email}.');
  // }

  // TEST DELETE CURRENT USER
  // await UserRepository().deleteCurrentUser();
  // debugPrint('Deleted current user ${validUser?.email}.');


  // RUN ONCE TO UPLOAD SEED WORDS TO FIRESTORE
  // YOU WILL NEED TO MAKE SURE THAT YOU MANUALLY LOGIN
  // ----------------------------------------------------
  // Sign in
  // await FirebaseAuth.instance.signInWithEmailAndPassword(
  //   email: "ztraboo@clemson.edu",
  //   password: "<hidden for privacy>",
  // );
  // // Call utility to upload seed words from CSV asset to Firestore words collection.
  // try {
  //   await SeedWordsUploader.uploadFromAsset(onProgress: (index, total) => debugPrint('Progress: $index/$total'));
  // } on FirebaseException catch (e) {
  //   debugPrint('Firestore: Error uploading seed words: ${e.code} — ${e.message}');
  // }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Read Right',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/landing',
      routes: {
        '/landing': (context) => const LandingPage(),
        '/reader-selection': (context) => const ReaderSelectionPage(),
        '/student-login': (context) => const StudentLoginPage(),
        '/student-passcode-verification': (context) => const StudentPasscodeVerificationPage(),
        '/student-word-dashboard': (context) => const StudentWordDashboardPage(),
        '/student-word-practice': (context) => const StudentWordPracticePage(),
        '/student-word-feedback': (context) => const StudentWordFeedbackPage(),
        '/teacher-login': (context) => const TeacherLoginPage(),
        '/teacher-register': (context) => const TeacherRegisterPage(),
        '/teacher-password-reset': (context) => const TeacherPasswordResetPage(),
        '/teacher-dashboard': (context) => const TeacherDashboardPage(),
        '/teacher-word-dashboard': (context) => const TeacherWordDashboardPage(),
        '/class-dashboard': (contyext) => const ClassDashboard(),
        '/class-student-details': (context) => const ClassStudentDetails(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
