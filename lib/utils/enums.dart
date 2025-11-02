
/// Enumeration for different word levels used in the application.
/// ---------------------------------------------------------------
enum WordLevel {
  sightWord,
  phonicsPattern,
  minimalPairs,
  custom
}

extension WordCategoryExtension on WordLevel {
  String get name => switch (this) {
      WordLevel.sightWord => 'Sight Word',
      WordLevel.phonicsPattern => 'Phonics Pattern',
      WordLevel.minimalPairs => 'Minimal Pairs',
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
