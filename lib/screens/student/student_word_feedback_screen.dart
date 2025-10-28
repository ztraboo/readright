// import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';

class StudentWordFeedbackPage extends StatefulWidget {

  const StudentWordFeedbackPage({Key? key}) : super(key: key);

  @override
  State<StudentWordFeedbackPage> createState() => _StudentWordFeedbackPageState();
}

class _StudentWordFeedbackPageState extends State<StudentWordFeedbackPage> {

  int _currentScore = 0;

  @override
  void initState() {
    super.initState();
    _currentScore = Random().nextInt(5) + 1;
    debugPrint("StudentWordFeedbackPage: init with score $_currentScore");
  } 

  void _handleRetry() {
    Navigator.pop(  
      context,
    );
  }

  void _handleDashboard() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/student-word-dashboard',
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 19),
              _buildYetiIllustration(),
              const SizedBox(height: 18),
              _buildSentenceSection(),
              // const SizedBox(height: 0),
              _buildStarRating(),
              const SizedBox(height: 0),
              _buildInstructions(),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRetryButton(),
                  const SizedBox(width: 20),
                  _buildDashboardButton(),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 130,
      color: AppColors.bgPrimaryGray,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(
              width: 349,
              child: Text(
                "Results for pronouncing",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Compact Display',
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 19),
            const SizedBox(
              width: 349,
              child: Text(
                'cat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  height: 0.61,
                ),
              ),
            ),
            const SizedBox(height: 31),
          ],
        ),
      ),
    );
  }

  Widget _buildYetiIllustration() {
    return SizedBox(
      width: 364,
      height: 371,
      child: _currentScore <= 2 ? SvgPicture.asset(
        'assets/mascot/yeti_upset.svg',
        semanticsLabel: 'Yeti Upset',
        fit: BoxFit.contain,
      ) : SvgPicture.asset(
        'assets/mascot/yeti_happy.svg',
        semanticsLabel: 'Yeti Happy',
        fit: BoxFit.contain,
      ),
    );
  }

  String _scoreMessage() {
    switch (_currentScore) {
      case 1:
        return 'Oh no — let\'s try again!';
      case 2:
        return 'Not bad, keep practicing!';
      case 3:
        return 'Good work!';
      case 4:
        return 'Great job!';
      case 5:
        return 'Excellent! Perfect pronunciation!';
      default:
        return '';
    }
  }

  Widget _buildSentenceSection() {
    return Container(
      width: double.infinity,
      height: 77,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC6C0).withOpacity(0.20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/quote-open-editor-svgrepo-com.svg',
            width: 23,
            height: 23,
            semanticsLabel: 'Quote Open',
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _scoreMessage(),
                    style: TextStyle(
                      fontFamily: 'SF Compact Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          SvgPicture.asset(
            'assets/icons/quote-close-editor-svgrepo-com.svg',
            width: 23,
            height: 23,
            semanticsLabel: 'Quote Close',
          ),
        ],
      ),
    );
  }
  
  Widget _buildStarRating() {
    // Simple visual star rating; use the 'score' passed into this widget for filled stars.
    const int totalStars = 5;

    // Map incoming score to a 0..totalStars range:
    // - If score is between 0 and totalStars, treat it as a direct star count.
    final int raw = _currentScore;
    debugPrint("StudentWordFeedbackPage: building star rating for score $raw");
    int filledCount = 0;
    if (raw >= 0 && raw <= totalStars) {
      filledCount = raw;
    } 

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(totalStars, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: SvgPicture.asset(
              index < filledCount
                  ? 'assets/icons/star-yellow-svgrepo-com.svg'
                  : 'assets/icons/star-gray-svgrepo-com.svg',
              width: 60,
              height: 60,
              semanticsLabel: index < filledCount
                  ? 'Star Yellow'
                  : 'Star Gray',
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      height: 86,
      padding: const EdgeInsets.all(10),
      child: const Center(
        child: SizedBox(
          width: 360,
          child: Text(
            'Click retry to try this word again or dashboard to return to the practice word list.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SF Compact Display',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.375,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return GestureDetector(
      onTap: _handleRetry,
      child: Container(
        height: 44,
        width: 136,
        decoration: BoxDecoration(
          color: AppColors.buttonPrimaryOrange,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: const Center(
          child: Text(
            'RETRY',
            style: AppStyles.buttonText,
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardButton() {
    return GestureDetector(
      onTap: _handleDashboard,
      child: Container(
        height: 44,
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.buttonPrimaryBlue,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: const Center(
          child: Text(
            'DASHBOARD',
            style: AppStyles.buttonText,
          ),
        ),
      ),
    );
  }

}
