
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readright/models/current_user_model.dart';
import 'package:readright/screens/reader_selection_screen.dart';
import 'package:readright/screens/student/student_login_screen.dart';


void main() {
  testWidgets('Student selection shows option for username and submit button', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CurrentUserModel(),
        child: MaterialApp(
          routes: {
            '/student-login': (context) => const StudentLoginPage(),
          },
          initialRoute: '/student-login',
        ),
      ),
    );

    // Verify button and textfield are visible
    expect(find.byType(StudentLoginPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('SUBMIT'), findsOneWidget);



    // Tap SUBMIT and verify no navigation because no entry in username
    await tester.tap(find.text('SUBMIT'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentLoginPage), findsOneWidget);
  });
}