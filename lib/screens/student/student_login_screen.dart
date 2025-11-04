import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/user_model.dart';
import '../../services/user_repository.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';
import '../../utils/enums.dart';
import '../../utils/validators.dart';

class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});

  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final UserModel? userModel;
  bool isVerifyingExistingLoginSession = true;

  @override
  void initState() {
    super.initState();

    // Check for existing user session on initialization
    // If a user is already signed in, we can skip the login screen
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
  }

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  Future<UserModel?> fetchUserModel() async {
    return await UserRepository().fetchCurrentUser();
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
            ? 'Sign in successful! Welcome back, ${userModel!.fullName}.'
            : 'Sign in successful!',
          duration: const Duration(seconds: 2),
          bgColor: AppColors.bgPrimaryDarkGrey,
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
          '/student-word-dashboard',
          (Route<dynamic> route) => false,
        );
    } 
  }

  Future<void> _handleSubmit() async {
    final username = usernameController.text.trim();
    
    if (username.isEmpty) {
      _showSnackBar(
        message: 'Please enter your username.',
        duration: const Duration(seconds: 2),
        bgColor: AppColors.bgPrimaryRed,
      );
      return;
    }

    // Check to see if the username exists in Firebase.
    final userModelExists = await UserRepository().fetchUserByUsername(username);
    if (userModelExists == null || userModelExists.id?.isEmpty == true) {
      _showSnackBar(
        message: 'The username "$username" does not exist.',
        duration: const Duration(seconds: 2),
        bgColor: AppColors.bgPrimaryRed,
      );
      return;
    }

    if (userModelExists.role != UserRole.student) {
      _showSnackBar(
        message: 'The username "$username" is not registered as a student but that is fine for testing purposes.',
        duration: const Duration(seconds: 2),
      );
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Navigate to the passcode verification screen and remove all previous routes
    // to prevent going back to the login screen.
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/student-passcode-verification',
      (Route<dynamic> route) => false,
      arguments: {
        'username': username,
        'passcode': userModelExists.id?.substring(0, 6),
        'email': userModelExists.email,
      },
    );
    
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 27),
            _buildUsernameField(),
            const SizedBox(height: 14),
            _buildSubmitButton(),
            const SizedBox(height: 25),
            // _buildYetiIllustration(),
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
          'Please enter your username below to begin. This value will be provided by your instructor.',
          style: AppStyles.subheaderText,
        ),
      ],
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
      validator: (value) => Validator.validateEmptyText("Username", value),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _handleSubmit,
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

  Widget _buildYetiIllustration() {
    return SizedBox(
      width: 618,
      height: 400,
      child: SvgPicture.asset(
        'assets/mascot/yeti_skating.svg',
        // width: 618, //327,
        // height: 569, //537,
        semanticsLabel: 'Yeti skating',
        clipBehavior: Clip.none,
      ),
    );
  }
}
