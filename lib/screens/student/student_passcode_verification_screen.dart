import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';

class StudentPasscodeVerificationPage extends StatefulWidget {
  const StudentPasscodeVerificationPage({super.key});

  @override
  State<StudentPasscodeVerificationPage> createState() =>
      _StudentPasscodeVerificationPageState();
}

class _StudentPasscodeVerificationPageState
    extends State<StudentPasscodeVerificationPage> {
  String _passcode = '';

  Future<void> _handleNext() async {
    if (_passcode.isEmpty || _passcode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete verification code'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Verifying passcode: $_passcode'),
          duration: Duration(seconds: 2),
        ),
      );

    await Future.delayed(const Duration(seconds: 3));

    // Navigate to the passcode verification screen and remove all previous routes
    // to prevent going back to the login screen.
    // Only navigate if the widget is still mounted after the delay.
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/student-word-dashboard',
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimaryWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimaryGray,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.buttonPrimaryBlue),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 46),
                _buildBody(),
                _buildYetiIllustration(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 200,
      color: AppColors.bgPrimaryGray,
      child: Stack(
        children: [
          Positioned(
            left: 90,
            top: 0,
            child: SizedBox(
              width: 275,
              height: 291,
              child: SvgPicture.asset(
                'assets/icons/coffee_mug.svg',
                width: 327,
                height: 537,
                semanticsLabel: 'Coffee Mug',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 27),
          _buildOTPField(),
          const SizedBox(height: 20),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passcode Verification',
          style: AppStyles.headerText.copyWith(height: 1.40),
        ),
        const SizedBox(height: 22),
        const Text(
          'Enter the verification code provided by your instructor.',
          style: AppStyles.subheaderText,
        ),
      ],
    );
  }

  Widget _buildOTPField() {
    return OtpTextField(
      numberOfFields: 6,
      borderColor: AppColors.textPrimaryBlue,
      focusedBorderColor: AppColors.bgPrimaryOrange,
      fillColor: Colors.white,
      filled: true,
      showFieldAsBox: true,
      borderWidth: 3.0,
      enabledBorderColor: AppColors.textPrimaryBlue,
      borderRadius: BorderRadius.circular(8),
      fieldWidth: 50,
      textStyle: const TextStyle(
        fontFamily: 'SF Pro Display',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      onCodeChanged: (String code) {
        setState(() {
          _passcode = code;
        });
      },
      onSubmit: (String verificationCode) {
        setState(() {
          _passcode = verificationCode;
        });
      },
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: _handleNext,
      child: Container(
        height: 44,
        width: 136,
        decoration: BoxDecoration(
          color: AppColors.bgPrimaryOrange,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: const Center(
          child: Text(
            'NEXT',
            style: AppStyles.buttonText,
          ),
        ),
      ),
    );
  }

  Widget _buildYetiIllustration() {
    return SizedBox(
      width: 618,
      height: 450, //569,
      child: SvgPicture.asset(
        'assets/mascot/yeti_skating.svg',
        semanticsLabel: 'Yeti skating',
        clipBehavior: Clip.none,
        fit: BoxFit.contain,
      ),
    );
  }
}
