import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:provider/provider.dart';
import 'package:readright/models/current_user_model.dart';
import 'package:readright/services/user_repository.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';

class StudentPasscodeVerificationPage extends StatefulWidget {
  final String? username;
  // final String? passcode;
  final String? email;

  const StudentPasscodeVerificationPage({super.key, this.username, this.email});

  @override
  State<StudentPasscodeVerificationPage> createState() =>
      _StudentPasscodeVerificationPageState();
}

class _StudentPasscodeVerificationPageState
    extends State<StudentPasscodeVerificationPage> {
  String _passcode = '';

  @override
  void initState() {
    super.initState();

    debugPrint("StudentPasscodeVerificationPage: init with username ${widget.username}");
  }

  void _showSnackBar({required String message, required Duration duration, Color? bgColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: bgColor ?? AppColors.bgPrimaryDarkGrey,
      ),
    );
  }

  Future<void> _handleNext() async {
    if (_passcode.isEmpty || _passcode.length < 6) {
      _showSnackBar(
        message: 'Please enter the complete verification code.',
        duration: const Duration(seconds: 2),
        bgColor: AppColors.bgPrimaryRed,
      );
      return;
    }

    _showSnackBar(
      message: 'Verifying passcode: $_passcode',
      duration: const Duration(seconds: 2),
    );

    // Check the passcode with Firebase to ensure it's valid.
    final isValid = await UserRepository().verifyClassPasscode(_passcode);

    if (!isValid) {
      _showSnackBar(
        message: 'Invalid verification code. Please try again.',
        duration: const Duration(seconds: 2),
        bgColor: AppColors.bgPrimaryRed,
      );
      return;
    }

    // Authenticate the user using Firebase Authentication (Email/Classcode).
    try {
      await UserRepository().signInFirebaseEmailPasswordUser(
        email: widget.email!,
        securePassword: _passcode,
      ); 
    } catch (e) {
      debugPrint('Failed to sign in as ${widget.username}: $e');

      _showSnackBar(
        message: 'Authentication failed. Please try again later.',
        duration: const Duration(seconds: 2),
        bgColor: AppColors.bgPrimaryRed,
      );
      return;
    } 

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
        Text(
          'Enter the verification code provided by your instructor.',
          style: AppStyles.subheaderText,
        ),
      ],
    );
  }

  Widget _buildOTPField() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: OtpTextField(
        keyboardType: TextInputType.text,
        numberOfFields: 6,
        borderColor: AppColors.textPrimaryBlue,
        focusedBorderColor: AppColors.bgPrimaryOrange,
        fillColor: Colors.white,
        filled: true,
        showFieldAsBox: true,
        borderWidth: 3.0,
        enabledBorderColor: AppColors.textPrimaryBlue,
        borderRadius: BorderRadius.circular(8),
        fieldWidth: 45,
        textStyle: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 20,
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
      ),
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
