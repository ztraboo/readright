import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:readright/models/user_model.dart';

import '../../../services/user_repository.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_styles.dart';
import '../../../utils/fireauth_utils.dart';
import '../../../utils/validators.dart';

class TeacherLoginPage extends StatefulWidget {
  const TeacherLoginPage({super.key});

  @override
  State<TeacherLoginPage> createState() => _TeacherLoginPageState();
}

class _TeacherLoginPageState extends State<TeacherLoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final PasswordPolicy firebaseAuthPasswordPolicy;
  late final UserModel? userModel;
  bool isVerifyingExistingLoginSession = true;

   @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    fetchUserModel().then((user) {
      setState(() {
        userModel = user;

        if (userModel != null) {
          // mobile — the Firebase Auth SDK persists the signed-in user across app restarts automatically.
          debugPrint('Restored user: ${userModel!.email}');
          navigateToDashboard();
        } else {
          debugPrint('No persisted user found.');
          isVerifyingExistingLoginSession = false;
        }
      });
    });

    // Grab the latest password policy from Firebase Authentication via Cloud Functions
    fetchFirebaseAuthPasswordPolicy();
  }

  Future<UserModel?> fetchUserModel() async {
    return await UserRepository().fetchCurrentUser();
  }

  void fetchFirebaseAuthPasswordPolicy() async {
    debugPrint('Fetching Firebase Auth password policy...');

    // Simulate fetching password policy from Firebase Authentication
    firebaseAuthPasswordPolicy = await fetchPasswordPolicy();
  }

  void _showSnackBar({required String message, required Duration duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  void navigateToDashboard() async {
      if (userModel != null) {
        debugPrint('User signed in successfully: ${userModel!.email}');
        _showSnackBar(
          message: (userModel!.fullName.trim().isNotEmpty == true)
            ? 'Sign in successful! Welcome back, ${userModel!.fullName}.'
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

  Future<void> _handleSignIn() async {

    // Validate the form (this triggers validators on TextFormField widgets)
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showSnackBar(
        message: 'Please fix the errors in the form.',
        duration: const Duration(seconds: 3)
      );
      return;
    }

    // Verify credentials with Firebase Authentication here using the emailController.text and passwordController.text
    final fireBaseAuth = UserRepository();

    userModel = await fireBaseAuth.signInFirebaseEmailPasswordUser(
      email: emailController.text,
      securePassword: passwordController.text
    );

    navigateToDashboard();
    
    // Could not sign in, so we just need to show the error message.
    debugPrint('Sign in failed for email: ${emailController.text}');
    _showSnackBar(
      message: 'Sign in failed. Please check your email and password.',
      duration: const Duration(seconds: 3)
    );
    return;
    
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
                  isVerifyingExistingLoginSession
                    ? _buildVerifyingLoginSession()
                    : _buildBody(),
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
              _buildEmailField(),
              const SizedBox(height: 14),
              _buildPasswordField(),
              const SizedBox(height: 30),
              _buildSignInButton(),
            ],
          ),
        ),
      );
  }

  // Displays a verifying login session progress indicator
  // Occurs when checking for existing user session on this screen.
  Widget _buildVerifyingLoginSession() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Verifying Login,',
          style: AppStyles.headerText,
        ),
        const SizedBox(height: 22),
        const Text(
          "Checking for existing user session ...",
          style: AppStyles.subheaderText,
        ),
        const SizedBox(height: 22),
        CircularProgressIndicator()
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back,',
          style: AppStyles.headerText,
        ),
        const SizedBox(height: 22),
        const Text(
          "Let's get started helping kids learn how to read better.",
          style: AppStyles.subheaderText,
        ),
      ],
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
      validator: (value) => Validator.validateEmptyText('Password', value),
    );
  }

  Widget _buildSignInButton() {
    return GestureDetector(
      onTap: _handleSignIn,
      child: Container(
        height: 44,
        width: 136,
        decoration: BoxDecoration(
          color: AppColors.bgPrimaryOrange,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Center(
          child: const Text(
            'SUBMIT',
            style: AppStyles.buttonText,
          ),
        ),
      ),
    );
  }
}
