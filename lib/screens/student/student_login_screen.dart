import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/current_user_model.dart';
import '../../models/user_model.dart';
import '../../services/class_repository.dart';
import '../../services/user_repository.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_styles.dart';
import '../../utils/enums.dart';
import '../../utils/validators.dart';
import '../../utils/push_notifications.dart';

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

  late final SharedPreferences prefs;

  @override
  void initState() {
    super.initState();

    // Check for existing user session on initialization
    // If a user is already signed in, we can skip the login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        userModel = context.read<CurrentUserModel>().user;

        if (userModel != null) {
          // mobile — the Firebase Auth SDK persists the signed-in user across app restarts automatically.
          debugPrint('Restored user: ${userModel!.email}');

          // Load class section for the current user
          ClassRepository().fetchClassesByStudent(userModel!.id as String).then((classModels) {
            if (classModels.isNotEmpty) {
              // ignore: use_build_context_synchronously
              context.read<CurrentUserModel>().classSection = classModels.first;
            }

            checkUserRoleAccess();
          });
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

  void checkUserRoleAccess() async {

    // Grab SharedPreferences instance
    prefs = await SharedPreferences.getInstance();

    // Perform an additional check to ensure that this is not a
    // student user logged in. We only want students.
    switch (userModel!.role) {
      case UserRole.teacher:
        debugPrint('Practicing words can only be accessed by students!');
        
        _showSnackBar(
          message: 'Practicing words can only be accessed by students!',
          duration: const Duration(seconds: 2),
          bgColor: AppColors.bgPrimaryRed,
        );

        Future.delayed(const Duration(seconds: 3)).then((_) {
          if (!mounted) return;
          setState(() {
            // Traverse back to the reader selection screen
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/reader-selection',
              (Route<dynamic> route) => false,
            );

            isVerifyingExistingLoginSession = false;
          });
        });

        break;
      case UserRole.student:
        final alreadyScheduled =
            prefs.getBool(AppConstants.prefDailyReminderScheduled) ?? false;

        if (!alreadyScheduled) {
          // Request notification permissions
          final granted =
              await DailyReminderService.requestPermissionsIfNeeded();

          if (granted) {
            // Schedule the daily reminder (just await, no assignment)
            await DailyReminderService.scheduleDailyNoonReminder();

            // Mark as scheduled in SharedPreferences
            await prefs.setBool(
              AppConstants.prefDailyReminderScheduled,
              true,
            );
          }
        }
        if (prefs.getBool(AppConstants.prefShowStudentWordDashboardScreen) == true) {
          navigateToDashboard();  
        } else {
          // ignore: use_build_context_synchronously
          final currentLevel = context.read<CurrentUserModel>().currentWordLevel ?? fetchWordLevelsIncreasingDifficultyOrder().first;
          debugPrint('StudentLoginPage: Navigating to word practice screen for level: ${currentLevel.name}');

          Navigator.pushNamedAndRemoveUntil(
            // ignore: use_build_context_synchronously
            context,
            '/student-word-practice',
            (Route<dynamic> route) => false,
            arguments: {
              // 'practiceWord': practiceWord,
              'wordLevel': wordLevelFromString(currentLevel.name),
            },
          );
        }
        
        break;
    }

    // Exit early to prevent navigating to the student dashboard
    // Important for teacher role case above
    return;
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

        Navigator.pushNamed(
          context,
          '/student-word-dashboard',
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

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Navigate to the passcode verification screen and remove all previous routes
    // to prevent going back to the login screen.
    Navigator.pushNamed(
      context,
      '/student-passcode-verification',
      arguments: {
        'username': username,
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
            _buildPushButton()
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

Widget _buildPushButton() {
  return ElevatedButton(
    onPressed: () async {
      debugPrint('Push button pressed');

      final granted =
          await DailyReminderService.requestPermissionsIfNeeded();

      debugPrint('Permission granted? $granted');

      if (granted) {
        await DailyReminderService.showImmediateTestNotification();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Immediate notification sent')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission denied')),
        );
      }
    },
    child: const Text('Trigger Test Notification'),
  );
}

}
