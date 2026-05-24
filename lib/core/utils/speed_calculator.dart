/// Speed estimation utilities.
///
/// These calculations are display-only and NOT safety-critical.
/// Actual speed depends on gearing, tire wear, and CVT slip — treat
/// all estimates as approximate.
class SpeedCalculator {
  // Private constructor — static-only utility class.
  SpeedCalculator._();

  // ---------------------------------------------------------------------------
  // SPEED ESTIMATION
  // ---------------------------------------------------------------------------

  /// Estimate vehicle speed (km/h) from engine RPM.
  ///
  /// This is a rough approximation for display purposes only.
  /// Default ratios approximate a 155 cc scooter in top gear.
  ///
  /// [rpm]              Engine speed in revolutions per minute.
  /// [finalDriveRatio]  Effective ratio between engine and wheel
  ///                    (default 9.8 — typical scooter CVT at high speed).
  /// [tireDiameterMm]   Overall tire diameter in mm
  ///                    (default 550 mm — approximate 110/70-12 tire).
  ///
  /// Returns 0 when [rpm] <= 0.
  static double estimatedSpeed({
    required int rpm,
    double finalDriveRatio = 9.8,
    double tireDiameterMm = 550.0,
  }) {
    if (rpm <= 0) return 0;
    final circumferenceMm = tireDiameterMm * 3.14159;
    final wheelRpm = rpm / finalDriveRatio;
    final speedMmPerMin = wheelRpm * circumferenceMm;
    final speedKmh = speedMmPerMin * 60 / 1000000;
    return speedKmh;
  }

  // ---------------------------------------------------------------------------
  // REV LIMIT PROXIMITY
  // ---------------------------------------------------------------------------

  /// Returns true when [rpm] is within 5% of [revLimitRpm].
  ///
  /// Used to trigger rev-limit warning indicators in the live monitor.
  static bool isApproachingRevLimit(int rpm, int revLimitRpm) {
    return rpm >= (revLimitRpm * 0.95).round();
  }
}
