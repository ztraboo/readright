
class AppScoring {

  /// The threshold score (0.0 to 1.0) required to pass a word practice session.
  /// For example, a value of 0.70 means the user must achieve at least 70% correct
  /// answers to pass.
  /// Adjust this value to make passing easier or harder.
  /// Default is 0.70 (70%).
  /// This should be about >= 3.5 stars correct out of 5.
  static const double passingThreshold = 0.70;

}