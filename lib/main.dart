import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:readright/utils/firestore_utils.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'screens/landing_screen.dart';
import 'screens/reader_selection_screen.dart';
import 'screens/student/student_login_screen.dart';
import 'screens/student/student_passcode_verification_screen.dart';
import 'screens/student/student_word_dashboard_screen.dart';
// Defer loading the heavy student practice screen (it pulls in FFmpeg).
import 'screens/student/student_word_practice_screen.dart' deferred as student_practice;
import 'screens/student/student_word_feedback_screen.dart';
import 'screens/teacher/login/teacher_login_screen.dart';
import 'screens/teacher/login/teacher_register_screen.dart';
import 'screens/teacher/login/teacher_password_reset_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/teacher/teacher_word_dashboard_screen.dart';
import 'screens/teacher/class/class_dashboard_screen.dart';
//import 'screens/teacher/class/class_student_details_screen.dart';

// import 'package:readright/services/user_repository.dart';
// import 'package:readright/utils/seed_words_uploader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure no user is signed in at app start
  // await UserRepository().signOutCurrentUser();


  // Anonymous sign-in for development/testing
  // try {
  //   final userCredential = await FirebaseAuth.instance.signInAnonymously();
  //   debugPrint('Signed in anonymously as ${userCredential.user?.uid}');
  // } catch (e) {
  //   debugPrint('Failed to sign in anonymously: $e');
  // }

  runApp(const MyApp());

  // Initialize Firebase asynchronously after the app has started to
  // reduce blocking work on startup. This avoids waiting on native
  // plugin initialization before the first frame is drawn.
  Future<void>(() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized');

      // Manually upload seed words from asset on app start
      // We do this here to ensure it's done once when the app starts.
      // This is a one-time operation; in a real app, you'd likely remove this after the initial upload.
      // SeedWordsUploader.uploadFromAsset().then((_) {
      //   debugPrint('Seed words upload completed.');
      // }).catchError((e) {
      //   debugPrint('Seed words upload failed: $e');
      // });

      // FirestoreUtils.renameCollection('students', 'student.progress').then((_) {
      //   debugPrint('Collection rename completed.');
      // }).catchError((e, st) {
      //   debugPrint('Collection rename failed: $e\n$st');
      // });

    } catch (e, st) {
      debugPrint('Firebase initialization failed: $e\n$st');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadRight',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/landing',
      routes: {
        '/landing': (context) => const LandingPage(),
        '/reader-selection': (context) => const ReaderSelectionPage(),
        '/student-login': (context) => const StudentLoginPage(),
        '/student-passcode-verification': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return StudentPasscodeVerificationPage(
            username: args is Map ? args['username'] : null,
            passcode: args is Map ? args['passcode'] : null,
            email: args is Map ? args['email'] : null,
          );
        },
        '/student-word-dashboard': (context) => const StudentWordDashboardPage(),
        '/student-word-practice': (context) => FutureBuilder<void>(
              future: student_practice.loadLibrary(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.done) {
                  return student_practice.StudentWordPracticePage();
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
        '/student-word-feedback': (context) => const StudentWordFeedbackPage(),
        '/teacher-login': (context) => const TeacherLoginPage(),
        '/teacher-register': (context) => const TeacherRegisterPage(),
        '/teacher-password-reset': (context) => const TeacherPasswordResetPage(),
        '/teacher-dashboard': (context) => const TeacherDashboardPage(),
        '/teacher-word-dashboard': (context) => const TeacherWordDashboardPage(),
        '/class-dashboard': (context) => const ClassDashboard(),
//        '/class-student-details': (context) => const ClassStudentDetails(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
