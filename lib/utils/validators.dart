import 'package:flutter/foundation.dart';

import 'fireauth_utils.dart';

/// A complete list of validators used throughout the app.
class Validator {

  // Check if a field is not empty.
  static String? validateEmptyText(String? fieldName, String? value) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required.';
    }

    return null;
  }

  /// Email Validation
  static String? validateEmail(String? value) {

    debugPrint('Validating email: $value');
    if (value == null || value.isEmpty) {
      return 'Email is required.';
    }

    // Regular expression for email validation
    final emailRegExp = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegExp.hasMatch(value)) {
      return 'Invalid email address.';
    }

    return null;
  }

  /// Password Validation using Firebase Authentication Password Policy configuration.
  static String? validatePassword(String? value, PasswordPolicy policy) {

    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }

    // Check for minimum password length
    if (value.length < policy.min) {
      return 'Password must be at least ${policy.min} characters long.';
    }

    // Check for maximum password length
    if (value.length > policy.max) {
      return 'Password must be at most ${policy.max} characters long.';
    }

    // Check for lowercase letters
    if (policy.needLower && !value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter.';
    }

    // Check for uppercase letters
    if (policy.needUpper && !value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }

    // Check for numbers
    if (policy.needNum && !value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }

    // Check for special characters
    if (policy.needSym && !value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character.';
    }

    return null;
  }

}