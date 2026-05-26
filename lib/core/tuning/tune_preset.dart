/// A zone-based fuel or ignition map delta applied by a customer preset.
///
/// Deltas are expressed as percentage changes within an RPM × TPS zone,
/// or as a flat degree/physical change for ignition maps.
/// The PresetEngine clamps all results to [MapDescriptor.safeMin/safeMax].
class MapZoneDelta {
  /// Which map to modify (e.g. 'fuel_map', 'ignition_map', 'vva_transition').
  final String mapName;

  /// Inclusive RPM row index range (0-based, refers to ECU defaultAxes.rpmPoints).
  final int rpmRowLow;
  final int rpmRowHigh;

  /// Inclusive TPS column index range (0-based).
  final int tpsColLow;
  final int tpsColHigh;

  /// Percentage change applied multiplicatively: newValue = original × (1 + pct/100).
  /// Use null if [absoluteDelta] is set instead.
  final double? percentDelta;

  /// Flat physical-unit delta added to existing value: newValue = original + absoluteDelta.
  /// Use for timing maps (degrees BTDC).
  final double? absoluteDelta;

  const MapZoneDelta({
    required this.mapName,
    required this.rpmRowLow,
    required this.rpmRowHigh,
    required this.tpsColLow,
    required this.tpsColHigh,
    this.percentDelta,
    this.absoluteDelta,
  }) : assert(
          percentDelta != null || absoluteDelta != null,
          'Supply either percentDelta or absoluteDelta',
        );

  double applyTo(double original) {
    if (percentDelta != null) return original * (1 + percentDelta! / 100);
    return original + absoluteDelta!;
  }
}

// ── Risk level ────────────────────────────────────────────────────────────────

enum PresetRisk { safe, caution, advanced }

// ── Tune preset ───────────────────────────────────────────────────────────────

/// A named tuning preset for a specific ECU/motorcycle model.
///
/// Presets are applied as a batch of [MapZoneDelta] operations.
/// All results are clamped to map safeMin/safeMax before writing.
class TunePreset {
  /// Unique machine ID.
  final String id;

  /// Display name shown to customers.
  final String name;

  /// One-line description.
  final String subtitle;

  /// Category grouping for the UI.
  final PresetCategory category;

  /// Which ECU this preset targets (must match EcuDefinition.id).
  final String ecuId;

  /// The map changes to apply.
  final List<MapZoneDelta> deltas;

  // ── Metadata shown to customer / mechanic ─────────────────────────────────

  /// 0.0–1.0 confidence that these values are safe for the stated ECU.
  /// Drops below 1.0 until the ECU's ROM offsets are hardware-validated.
  final double confidenceScore;

  /// Qualitative heat/stress estimate for engine and electrical components.
  final PresetRisk riskLevel;

  /// Minimum fuel octane required for this tune to be safe.
  final int recommendedOctaneMin;

  /// Brief explanation of the AFR strategy and target range.
  final String afrTargetExplanation;

  /// Short bullet-point warnings shown prominently in the UI.
  final List<String> warnings;

  /// Expected positive outcomes.
  final List<String> benefits;

  /// Expected trade-offs or negative side effects.
  final List<String> sideEffects;

  /// Hardware or software mods this preset assumes are already fitted.
  final List<String> requiredMods;

  /// Estimated power increase as a percentage over stock (purely indicative).
  final double? estimatedPowerGainPct;

  /// Estimated fuel consumption change as percentage (negative = improvement).
  final double? estimatedFuelChangePct;

  const TunePreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.category,
    required this.ecuId,
    required this.deltas,
    required this.confidenceScore,
    required this.riskLevel,
    required this.recommendedOctaneMin,
    required this.afrTargetExplanation,
    required this.warnings,
    required this.benefits,
    required this.sideEffects,
    this.requiredMods = const [],
    this.estimatedPowerGainPct,
    this.estimatedFuelChangePct,
  });
}

enum PresetCategory {
  performance,
  daily,
  specialized,
}

extension PresetCategoryLabel on PresetCategory {
  String get label => switch (this) {
        PresetCategory.performance => 'Performance',
        PresetCategory.daily => 'Daily Use',
        PresetCategory.specialized => 'Specialized',
      };
}
