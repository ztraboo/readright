//Test changes - Jon
import 'package:flutter/material.dart';
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

void main() {
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
