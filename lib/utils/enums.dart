import 'package:flutter/material.dart';

// Enumaration for audio codecs used in the application.
// ---------------------------------------------------------------
enum AudioCodec {
  pcm16,
  wav,
  aac,
  unknown
}

extension AudioCodecExtension on AudioCodec {
  String get name => switch (this) {
      AudioCodec.pcm16 => 'PCM 16-bit',
      AudioCodec.wav => 'WAV',
      AudioCodec.aac => 'AAC',
      AudioCodec.unknown => 'Unknown',
  };
}

// Enumeration for different word levels used in the application.
// Keep the order of the enum values as is; they represent increasing difficulty/order. 
// ---------------------------------------------------------------
enum WordLevelState {
  isLocked,
  isUnlocked,
  isCompleted
}

enum WordLevel {
  prePrimer,
  primer,
  firstGrade,
  secondGrade,
  thirdGrade,
  fourthGrade,
  fifthGrade,
  custom
}

extension WordCategoryExtension on WordLevel {
  String get name => switch (this) {
      WordLevel.prePrimer => 'Pre-Primer',
      WordLevel.primer => 'Primer',
      WordLevel.firstGrade => 'First Grade',
      WordLevel.secondGrade => 'Second Grade',
      WordLevel.thirdGrade => 'Third Grade',
      WordLevel.fourthGrade => 'Fourth Grade',
      WordLevel.fifthGrade => 'Fifth Grade',
      WordLevel.custom => 'Custom',
  };

  Color get backgroundColor => switch (this) {
      WordLevel.prePrimer =>  const Color(0xFFE3F2FD), // Light Blue
      WordLevel.primer => const Color(0xFFFFF9C4), // Light Yellow
      WordLevel.firstGrade => const Color(0xFFC8E6C9), // Light Green
      WordLevel.secondGrade => const Color(0xFFFFE0B2), // Light Orange
      WordLevel.thirdGrade => const Color(0xFFD1C4E9), // Light Purple
      WordLevel.fourthGrade => const Color(0xFFFFCDD2), // Light Red
      WordLevel.fifthGrade => const Color(0xFFB2DFDB), // Light Teal
      WordLevel.custom => const Color(0xFFE0E0E0), // Light Grey
  };

}

/// Helper function to convert a string to a WordLevel enum value.
WordLevel wordLevelFromString(String level) {
  final input = level.trim().toLowerCase();
  for (final wl in WordLevel.values) {
    // match by enum identifier (e.g. "prePrimer", "firstGrade")
    if (wl.toString().split('.').last.toLowerCase() == input) {
      return wl;
    }
    // match by display name from the extension (e.g. "Pre-Primer", "First Grade")
    if (wl.name.toLowerCase() == input) {
      return wl;
    }
  }
  return WordLevel.custom;
} 

// Order levels by their enum order
// This should return levels by there increasing difficulty/order.
List<WordLevel> fetchWordLevelsIncreasingDifficultyOrder() {
  return WordLevel.values;
}

/// Enumeration for different users.
/// ---------------------------------------------------------------

//// UserRole defines the roles a user can have in the application.
enum UserRole {
  teacher,
  student
}

extension UserRoleExtension on UserRole {
  String get name => switch (this) {
      UserRole.teacher => 'Teacher',
      UserRole.student => 'Student',
  };
}

enum VerificationStatus { unknown, pending, submitted, underReview, approved, rejected }

extension VerificationStatusExtension on VerificationStatus {
  String get name => switch (this) {
      VerificationStatus.unknown => 'Unknown',
      VerificationStatus.pending => 'Pending',
      VerificationStatus.submitted => 'Submitted',
      VerificationStatus.underReview => 'Under Review',
      VerificationStatus.approved => 'Approved',
      VerificationStatus.rejected => 'Rejected',
  };
}
