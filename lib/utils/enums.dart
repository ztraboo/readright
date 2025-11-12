
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
}

/// Helper function to convert a string to a WordLevel enum value.
WordLevel wordLevelFromString(String level) {
  try {
    return WordLevel.values.byName(level);
  } catch (_) {
    return WordLevel.custom;
  }
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
