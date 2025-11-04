import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/user_model.dart';
import '../../../services/user_repository.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_styles.dart';
import '../../../utils/enums.dart';
import '../../../utils/fireauth_utils.dart';
import '../../../utils/validators.dart';
class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  State<TeacherRegisterPage> createState() => _TeacherRegisterPageState();
}

class _TeacherRegisterPageState extends State<TeacherRegisterPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController institutionController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final PasswordPolicy firebaseAuthPasswordPolicy;
  late final UserModel? userModel;

  @override
  void initState() {
    super.initState();

    // Grab the latest password policy from Firebase Authentication via Cloud Functions
    fetchFirebaseAuthPasswordPolicy();
  }

  void fetchFirebaseAuthPasswordPolicy() async {
    debugPrint('Fetching Firebase Auth password policy...');

    // Simulate fetching password policy from Firebase Authentication
    firebaseAuthPasswordPolicy = await fetchPasswordPolicy();
  }

  void _showSnackBar({required String message, required Duration duration, Color? bgColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: bgColor ?? AppColors.bgPrimaryDarkGrey,
      ),
    );
  }

  void navigateToDashboard() async {
      if (userModel != null) {
        debugPrint('User signed in successfully: ${userModel!.email}');
        _showSnackBar(
          message: (userModel!.fullName.trim().isNotEmpty == true)
            ? 'Sign in successful! Welcome, ${userModel!.fullName}.'
            : 'Sign in successful!',
          duration: const Duration(seconds: 2)
        );

        /**********************************************************
        Navigate to teacher dashboard after verifying login fields

        The fields must still be filled because of the null check,
        but any dummy values work for now
        **********************************************************/
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/teacher-dashboard',
          (Route<dynamic> route) => false,
        );
    } 
  }

  // Navigate to the teacher login screen if the user taps "Sign In"
  void _handleSignIn() {
    Navigator.pushNamed(
      context,
      '/teacher-login',
    );
  }

  Future<void> _handleSignUp() async {

    // Validate the form (this triggers validators on TextFormField widgets)
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showSnackBar(
        message: 'Please fix the errors in the form.',
        duration: const Duration(seconds: 3),
        bgColor: AppColors.bgPrimaryRed,
      );
      return;
    }

    // Create credentials with Firebase Authentication here using the controllers text completed by the user.

    // Try to create the user with Firebase Authentication
    try {
      userModel = await UserRepository().createFirebaseEmailPasswordUser(
        user: UserModel(
          email: emailController.text,
          role: UserRole.teacher,
          fullName: fullNameController.text,
          local: 'en-US',
          institution: institutionController.text,
          username: usernameController.text,

          // TODO: Skipping these checks for now. May need to implement email verification later.
          // Everyone that creates and account here is automatically verified and have approved email status.
          isEmailVerified: true,
          verificationStatus: VerificationStatus.approved
        ),
        securePassword: passwordController.text,
      );
    } on FirebaseException catch (e, st) {
      debugPrint("Error during user creation: ${e.toString()}\n$st");

      if (e.code == 'email-already-in-use') {
        _showSnackBar(
          message: 'The email address is already in use by another account.',
          duration: const Duration(seconds: 3),
          bgColor: AppColors.bgPrimaryRed,
        );
      } else if (e.code == 'weak-password') {
        _showSnackBar(
          message: 'The password provided is too weak.',
          duration: const Duration(seconds: 3),
          bgColor: AppColors.bgPrimaryRed,
        );
      } else if (e.code == 'invalid-email') {
        _showSnackBar(
          message: 'The email address is not valid.',
          duration: const Duration(seconds: 3),
          bgColor: AppColors.bgPrimaryRed,
        );
      } else if (e.code == 'operation-not-allowed') {
        _showSnackBar(
          message: 'Email/password accounts are not enabled.',
          duration: const Duration(seconds: 3),
          bgColor: AppColors.bgPrimaryRed,
        );
      } else if (e.code == 'network-request-failed') {
        _showSnackBar(
          message: 'Network error. Please check your internet connection.',
          duration: const Duration(seconds: 3),
          bgColor: AppColors.bgPrimaryRed,
        );
      } else if (e.code == 'too-many-requests') {
        _showSnackBar(
          message: 'Too many requests. Please try again later.',
          duration: const Duration(seconds: 3),
          bgColor: AppColors.bgPrimaryRed,
        );
      } else if (e.code == 'username-already-exists') {
        _showSnackBar(
          message: 'The username "${usernameController.text}" is already in use.',
          duration: const Duration(seconds: 3),
          bgColor: AppColors.bgPrimaryRed,
        );
      } else {
        // Could not create user, so we just need to show the error message.
        debugPrint('User creation failed for email: ${emailController.text}');
        _showSnackBar(
          message: 'User creation failed. Please check your registration fields.',
          duration: const Duration(seconds: 3),
          bgColor: AppColors.bgPrimaryRed,
        );
      }

      // Make sure to return so we don't navigate to the teacher dashboard
      return;
    }

    navigateToDashboard();
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 46),
                  _buildBody(),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 27),
            _buildFullNameField(),
            const SizedBox(height: 14),
            _buildInstitutionField(),
            const SizedBox(height: 14),
            _buildUsernameField(),
            const SizedBox(height: 14),
            _buildEmailField(),
            const SizedBox(height: 14),
            _buildPasswordField(),
            const SizedBox(height: 30),
            _buildSignUpButton(),
            const SizedBox(height: 25),
            _buildSignInMessage(),
          ],
        ),
      ),
    );
  }

    Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Help Kids Read,',
          style: AppStyles.headerText,
        ),
        const SizedBox(height: 22),
        const Text(
          "Complete the following fields to create an account:",
          style: AppStyles.subheaderText,
        ),
      ],
    );
  }

  Widget _buildFullNameField() {
    return TextFormField(
      controller: fullNameController,
      textInputAction: TextInputAction.done,
      style: AppStyles.textFieldText,
      decoration: InputDecoration(
        labelText: 'Full Name',
        hintText: 'e.g., Jane Doe',
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: SvgPicture.asset(
            'assets/icons/user-svgrepo-com.svg',
            width: 34,
            alignment: Alignment.centerLeft,
            semanticsLabel: 'User Icon',
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 5),
        ),
      ),
      validator: (value) => Validator.validateEmptyText("Full Name", value),
    );
  }

  Widget _buildInstitutionField() {
    return TextFormField(
      controller: institutionController,
      textInputAction: TextInputAction.done,
      style: AppStyles.textFieldText,
      decoration: InputDecoration(
        labelText: 'Institution',
        hintText: 'e.g., Example School',
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: SvgPicture.asset(
            'assets/icons/school-svgrepo-com.svg',
            width: 34,
            alignment: Alignment.centerLeft,
            semanticsLabel: 'School Icon',
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 5),
        ),
      ),
      validator: (value) => Validator.validateEmptyText("Institution", value),
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: usernameController,
      textInputAction: TextInputAction.done,
      style: AppStyles.textFieldText,
      decoration: InputDecoration(
        labelText: 'Username',
        hintText: 'e.g., janedoe',
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: SvgPicture.asset(
            'assets/icons/username-svgrepo-com.svg',
            width: 34,
            alignment: Alignment.centerLeft,
            semanticsLabel: 'Username Icon',
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 5),
        ),
      ),
      validator: (value) => Validator.validateUsername(value),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: emailController,
      textInputAction: TextInputAction.done,
      style: AppStyles.textFieldText,
      decoration: InputDecoration(
        labelText: 'E-mail',
        hintText: 'e.g., first.last@example.com',
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: SvgPicture.asset(
            'assets/icons/email-svgrepo-com.svg',
            width: 34,
            alignment: Alignment.centerLeft,
            semanticsLabel: 'Password Icon',
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 5),
        ),
      ),
      validator: (value) => Validator.validateEmail(value, ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      textInputAction: TextInputAction.done,
      style: AppStyles.textFieldText,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Password',
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: SvgPicture.asset(
            'assets/icons/password-minimalistic-input-svgrepo-com.svg',
            width: 34,
            alignment: Alignment.centerLeft,
            semanticsLabel: 'Password Icon',
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.zero),
          borderSide: BorderSide(color: AppColors.textPrimaryBlue, width: 5),
        ),
      ),
      validator: (value) => Validator.validatePassword(value, firebaseAuthPasswordPolicy),
    );
  }

  Widget _buildSignUpButton() {
    return GestureDetector(
      onTap: _handleSignUp,
      child: Container(
        height: 44,
        width: 136,
        decoration: BoxDecoration(
          color: AppColors.bgPrimaryOrange,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Center(
          child: const Text(
            'REGISTER',
            style: AppStyles.buttonText,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInMessage() {
    return GestureDetector(
      onTap: _handleSignIn,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            "Already have an account? ",
            style: AppStyles.subheaderText,
          ),
          Text(
            "Sign In",
            style: AppStyles.navigationText,
          ),
        ],
      ),
    );
  }

}