
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

