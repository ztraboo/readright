import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readright/models/current_user_model.dart';
import 'package:readright/screens/reader_selection_screen.dart';
import 'package:readright/screens/student/student_login_screen.dart';
import 'package:readright/screens/teacher/login/teacher_login_screen.dart';
import 'package:readright/screens/teacher/login/teacher_register_screen.dart';



void main() {
  testWidgets('Teacher Selection shows sign in and it does NOT navigate', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CurrentUserModel(),
        child: MaterialApp(
          routes: {
            '/teacher-login': (context) => const TeacherLoginPage(),
          },
          initialRoute: '/teacher-login',
        ),
      ),
    );

    // Verify both buttons are visible
    expect(find.byType(TeacherLoginPage), findsOneWidget);
    // wait for screen to load
    await tester.pump(const Duration(seconds: 5));

    // Tap SIGN IN and verify no navigation because no persistent user
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherLoginPage), findsOneWidget);

  });
}