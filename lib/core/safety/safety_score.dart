import 'safety_validator.dart';

/// Aggregates pre-remap and tune safety scores into a single status indicator.
/// Used by the persistent status bar throughout the app.
class SafetyScore {
  /// Derive a [SafetyLevel] from a numeric score (0-100).
  ///
  ///   >= 85  → approved
  ///   70-84  → warning
  ///   < 70   → hardLock
  static SafetyLevel levelFromScore(int score) {
    if (score >= 85) return SafetyLevel.approved;
    if (score >= 70) return SafetyLevel.warning;
    return SafetyLevel.hardLock;
  }

  /// Short Tagalog/English label shown in the status bar.
  ///
  ///   approved  → 'LIGTAS'  (safe)
  ///   warning   → 'BABALA'  (warning)
  ///   hardLock  → 'BLOCKED'
  static String labelFromScore(int score) {
    final level = levelFromScore(score);
    return switch (level) {
      SafetyLevel.hardLock => 'BLOCKED',
      SafetyLevel.warning => 'BABALA',
      SafetyLevel.approved => 'LIGTAS',
    };
  }

  /// Colored circle icon for quick visual status at a glance.
  static String iconFromScore(int score) {
    return switch (levelFromScore(score)) {
      SafetyLevel.hardLock => '🔴',
      SafetyLevel.warning => '🟡',
      SafetyLevel.approved => '🟢',
    };
  }
}
