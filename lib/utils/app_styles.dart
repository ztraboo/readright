import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppStyles {

  // Logo Text Styles
  // ----------------------------------

  static const TextStyle readTextBold = TextStyle(
    fontFamily: 'SF Compact Rounded',
    fontSize: 64,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimaryBlack,
    height: 1.0,
  );

  static const TextStyle rightText = TextStyle(
    fontFamily: 'SF Compact Rounded',
    fontSize: 48,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimaryBlack,
    height: 0.5,
  );

  // General Text Styles
  // ----------------------------------

  static const TextStyle headerText = TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: Colors.black,
    height: 0.61,
  );

  static const TextStyle subheaderText = TextStyle(
    fontFamily: 'SF Compact Display',
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    height: 1.1,
  );
  
  // Button Text Styles
  // ----------------------------------
  static const TextStyle buttonText = TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.23,
    color: Colors.white,
  );

  // TextField Text Styles
  // ----------------------------------
  static const TextStyle textFieldText = TextStyle(
    fontFamily: 'SF Compact Display',
    fontSize: 26, 
    fontWeight: FontWeight.w400,
    color: Color(0xFF303030),
  );

}
