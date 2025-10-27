//Test changes - Jon
import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';
import 'screens/reader_selection_screen.dart';
import 'screens/teacher/teacher_login_screen.dart';
import 'screens/teacher/teacher_register_screen.dart';
import 'screens/teacher/teacher_password_reset_screen.dart';

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
        '/teacher-login': (context) => const TeacherLoginPage(),
        '/teacher-register': (context) => const TeacherRegisterPage(),
        '/teacher-password-reset': (context) => const TeacherPasswordResetPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
