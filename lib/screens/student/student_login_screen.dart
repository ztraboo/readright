import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';

class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});

  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Class passcode sent to $email'),
      ),
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
          _buildEmailField(),
          const SizedBox(height: 14),
          _buildSubmitButton(),
          const SizedBox(height: 25),
          // _buildYetiIllustration(),
        ],
      ),
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
          'Please enter your email address below to begin. A class passcode will be sent to your email and your instructor will also be notified.',
          style: AppStyles.subheaderText,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return SizedBox(
      width: 396,
      height: 54,
      child: Stack(
        children: [
          Container(
            // margin: const EdgeInsets.only(left: 1),
            width: 396,
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: AppColors.textPrimaryBlue,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/email-svgrepo-com.svg',
                  width: 34,
                  alignment: Alignment.centerLeft,
                  semanticsLabel: 'Email Icon',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppStyles.textFieldText,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'E-mail',
                      hintStyle: AppStyles.textFieldText,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
