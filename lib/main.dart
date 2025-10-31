//Test changes - Jon
import 'package:flutter/material.dart';

// Firebase packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

// import 'utils/seed_words_uploader.dart';

Future<void> main() async {

  // Use default Firebase options for app initialization
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
