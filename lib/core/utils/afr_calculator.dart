/// Air/Fuel Ratio calculation utilities.
///
/// Safety note: AFR accuracy depends on sensor quality.
/// All wideband-derived values should be treated as reference only.
/// Narrowband estimates (see [estimatedAfrFromNarrowbandVoltage]) are
/// display-only and NOT suitable for tuning decisions.
class AfrCalculator {
  // Private constructor — static-only utility class.
  AfrCalculator._();

  /// Stoichiometric AFR for gasoline (14.7:1).
  static const double stoichiometric = 14.7;

  // ---------------------------------------------------------------------------
  // FUEL TRIM
  // ---------------------------------------------------------------------------

  /// Fuel trim percentage: how much fuel must be added or removed to reach
  /// the target AFR from the current measured AFR.
  ///
  /// Formula: ((currentAfr - targetAfr) / currentAfr) * 100
  ///
  ///   Positive = lean (need to add fuel)
  ///   Negative = rich (need to remove fuel)
  ///
  /// Returns 0 when [currentAfr] <= 0 to prevent divide-by-zero.
  static double fuelTrimPercent({
    required double currentAfr,
    required double targetAfr,
  }) {
    if (currentAfr <= 0) return 0; // safety: prevent divide by zero
    return ((currentAfr - targetAfr) / currentAfr) * 100;
  }

  // ---------------------------------------------------------------------------
  // LAMBDA CONVERSIONS
  // ---------------------------------------------------------------------------

  /// Convert an AFR value to lambda ratio (AFR / stoichiometric).
  ///
  /// Lambda = 1.0 is stoichiometric. < 1.0 is rich, > 1.0 is lean.
  static double lambdaFromAfr(double afr) => afr / stoichiometric;

  /// Convert a lambda ratio back to AFR (lambda * stoichiometric).
  static double afrFromLambda(double lambda) => lambda * stoichiometric;

  // ---------------------------------------------------------------------------
  // NARROWBAND ESTIMATION (DISPLAY ONLY)
  // ---------------------------------------------------------------------------

  /// Estimate AFR from a narrowband O2 sensor voltage reading.
  ///
  /// IMPORTANT: This is a rough approximation for display purposes ONLY.
  /// Real AFR measurement requires a wideband sensor.
  ///
  /// Narrowband range: 0 V = rich, 1 V = lean, ~0.45 V = stoichiometric.
  /// Linear interpolation: 0 V → AFR 11.5 (very rich), 1 V → AFR 15.5 (lean).
  /// Input voltage is clamped to [0.0, 1.0].
  static double estimatedAfrFromNarrowbandVoltage(double voltage) {
    final v = voltage.clamp(0.0, 1.0);
    return 11.5 + (v * 4.0);
  }

  // ---------------------------------------------------------------------------
  // DANGER / WARNING CHECKS
  // ---------------------------------------------------------------------------

  /// Returns true when the AFR is in a dangerous zone that risks engine damage.
  ///
  ///   < 12.0 at any RPM  → too rich (fouling, carbon build-up)
  ///   > 15.0 at high RPM → too lean (detonation, piston damage)
  static bool isAfrDangerous(double afr, {bool atHighRpm = false}) {
    if (afr < 12.0) return true; // too rich at any RPM
    if (atHighRpm && afr > 15.0) return true; // too lean at high RPM
    return false;
  }

  /// Returns true when the AFR is approaching (but not yet at) a danger zone.
  ///
  ///   < 12.5 or > 14.5 → warning range
  static bool isAfrWarning(double afr) {
    return afr < 12.5 || afr > 14.5;
  }
}
