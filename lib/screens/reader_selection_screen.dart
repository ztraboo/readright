import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'student/student_login_screen.dart';
import 'teacher/teacher_login_screen.dart';
import '../utils/app_colors.dart';
import '../utils/app_styles.dart';

class ReaderSelectionPage extends StatelessWidget {
  const ReaderSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimaryGray,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 97),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Column(
                children: [
                  Text('Reader Selection', style: AppStyles.headerText),
                  SizedBox(height: 10),
                  Text(
                    'Select your role to begin learning how to pronounce words.',
                    textAlign: TextAlign.center,
                    style: AppStyles.subheaderText,
                  ),
                ],
              ),
            ),
            SizedBox(height: 5),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: AlignmentGeometry.center,
                  children: [
                    Container(
                      width: 350,
                      height: 350,
                      decoration: ShapeDecoration(
                        color: const Color(0xFF303030),
                        shape: OvalBorder(),
                      ),
                    ),
                    Container(
                      width: 310,
                      height: 310,
                      decoration: ShapeDecoration(
                        color: const Color(0xFFF88843),
                        shape: OvalBorder(),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(28.0),
                      child: SvgPicture.asset(
                        'assets/mascot/yeti_skating.svg',
                        width: 327,
                        height: 537,
                        semanticsLabel: 'Yeti skating',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 60),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to instructor flow; allow navigation back to this page if needed.
                        Navigator.pushNamed(context, '/teacher-login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonPrimaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(1000),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        'INSTRUCTOR',
                        style: AppStyles.buttonText,
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to student flow; allow navigation back to this page if needed.
                        Navigator.pushNamed(context, '/student-login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonPrimaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(1000),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        'STUDENT',
                        style: AppStyles.buttonText, 
                      ),
                    ),
                  ),
                  SizedBox(height: 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
