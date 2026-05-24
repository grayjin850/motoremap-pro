import '../../models/motorcycle_model.dart';
import '../../models/tune_profile.dart';

enum CalculationMode { preRemap, tuneSafety }

enum SafetyLevel { approved, warning, hardLock }

class ValidationWarning {
  final String code;
  final String message;
  final bool isBlocking;

  const ValidationWarning({
    required this.code,
    required this.message,
    required this.isBlocking,
  });
}

class SafetyValidationResult {
  final int score; // 0-100
  final SafetyLevel level;
  final List<ValidationWarning> warnings;
  final bool vvaZoneWarningRequired;
  final bool backupRequired; // always true — cannot proceed without backup

  const SafetyValidationResult({
    required this.score,
    required this.level,
    required this.warnings,
    required this.vvaZoneWarningRequired,
    required this.backupRequired,
  });

  /// Can only generate reference sheet when not hard-locked AND backup is done.
  bool get canGenerateReferenceSheet =>
      level != SafetyLevel.hardLock && !backupRequired;

  /// Mechanic must acknowledge warnings before proceeding.
  bool get requiresAcknowledgment => level == SafetyLevel.warning;
}

class SafetyValidator {
  // ---------------------------------------------------------------------------
  // PRE-REMAP MODE
  //
  // Start at 100. Apply deductions only.
  //   -20 per active fault code
  //   -15 if engine not warmed up (temp < 70 °C)
  //   -10 per unchecked checklist item (0-7 items)
  // Score clamped to 0 minimum (never negative).
  //
  // Safety levels (shared with tune safety mode):
  //   >= 85  → approved
  //   70-84  → warning
  //   < 70   → hardLock
  // ---------------------------------------------------------------------------

  static SafetyValidationResult calculatePreRemapScore({
    required int activeFaultCodeCount,
    required bool engineWarmedUp,
    required int uncheckedChecklistItems, // 0-7
    required bool backupConfirmed,
  }) {
    final warnings = <ValidationWarning>[];
    int score = 100;

    // Fault code deductions: -20 each
    if (activeFaultCodeCount > 0) {
      score -= activeFaultCodeCount * 20;
      warnings.add(ValidationWarning(
        code: 'PRE_FAULT_CODES',
        message:
            '$activeFaultCodeCount active fault code(s) detected. '
            'Resolve before remapping.',
        isBlocking: activeFaultCodeCount >= 3,
      ));
    }

    // Engine warm-up deduction: -15
    if (!engineWarmedUp) {
      score -= 15;
      warnings.add(const ValidationWarning(
        code: 'PRE_ENGINE_COLD',
        message:
            'Engine not warmed up (temp < 70 °C). '
            'Run engine to operating temperature first.',
        isBlocking: false,
      ));
    }

    // Unchecked checklist items: -10 each (items clamped to 0-7)
    final clampedItems = uncheckedChecklistItems.clamp(0, 7);
    if (clampedItems > 0) {
      score -= clampedItems * 10;
      warnings.add(ValidationWarning(
        code: 'PRE_CHECKLIST_INCOMPLETE',
        message:
            '$clampedItems checklist item(s) not confirmed. '
            'Complete all pre-remap checks.',
        isBlocking: clampedItems >= 5,
      ));
    }

    // Clamp score: never negative
    score = score.clamp(0, 100);

    // Backup warning — always required regardless of score
    if (!backupConfirmed) {
      warnings.add(const ValidationWarning(
        code: 'PRE_NO_BACKUP',
        message:
            'ECU backup not confirmed. A backup MUST be taken before '
            'any remap operation.',
        isBlocking: true,
      ));
    }

    final level = _levelFromScore(score);

    return SafetyValidationResult(
      score: score,
      level: level,
      warnings: warnings,
      vvaZoneWarningRequired: false,
      backupRequired: !backupConfirmed,
    );
  }

  // ---------------------------------------------------------------------------
  // TUNE SAFETY MODE
  //
  // Start at 0. Apply additions.
  //   +30 if AFR targets within safe range for the model
  //   +30 if timing advance within compression-derived floor (NEVER admin value)
  //   +20 if rev limit within safe mechanical limit
  //   +20 if no knock zones aggressively tuned
  //
  // FLOOR VALIDATION (model.maxTimingAdvance, derived from compressionRatio):
  //   >= 11.5:1 → absolute max +3°
  //   >= 11.0:1 → absolute max +4°
  //   <  11.0:1 → absolute max +5°
  // This CANNOT be overridden by admin settings.
  //
  // Score clamped 0-100.
  // ---------------------------------------------------------------------------

  static SafetyValidationResult calculateTuneSafetyScore({
    required MotorcycleModel model,
    required TuneProfile profile,
    required bool backupConfirmed,
  }) {
    final warnings = <ValidationWarning>[];
    int score = 0;

    // --- AFR check: +30 ---
    final afrMidSafe = isAfrSafe(profile.afrTargetMid, model);
    final afrWotSafe = isAfrSafe(profile.afrTargetWot, model);
    if (afrMidSafe && afrWotSafe) {
      score += 30;
    } else {
      if (!afrMidSafe) {
        warnings.add(ValidationWarning(
          code: 'TUNE_AFR_MID_UNSAFE',
          message:
              'Mid-range AFR target (${profile.afrTargetMid}) is outside '
              'safe range [${model.safeAfrMin}, ${model.safeAfrMax}].',
          isBlocking: profile.afrTargetMid < model.safeAfrMin,
        ));
      }
      if (!afrWotSafe) {
        warnings.add(ValidationWarning(
          code: 'TUNE_AFR_WOT_UNSAFE',
          message:
              'WOT AFR target (${profile.afrTargetWot}) is outside '
              'safe range [${model.safeAfrMin}, ${model.safeAfrMax}].',
          isBlocking: profile.afrTargetWot < model.safeAfrMin,
        ));
      }
    }

    // --- Timing advance check: +30 ---
    // CRITICAL: use model.maxTimingAdvance (compression-derived), NEVER admin value.
    if (isTimingAdvanceSafe(profile.timingAdvanceDeg, model)) {
      score += 30;
    } else {
      warnings.add(ValidationWarning(
        code: 'TUNE_TIMING_UNSAFE',
        message:
            'Timing advance (${profile.timingAdvanceDeg}°) exceeds '
            'compression-derived maximum of ${model.maxTimingAdvance}° '
            'for compression ratio ${model.compressionRatio}:1. '
            'This is a hard safety floor — admin overrides are not permitted.',
        isBlocking: true,
      ));
    }

    // --- Rev limit check: +20 ---
    // profile.revLimitRaise is a delta; model.maxSafeRevRaise is an absolute max.
    final proposedRevLimit = model.stockRevLimitHard + profile.revLimitRaise;
    if (isRevLimitSafe(proposedRevLimit, model)) {
      score += 20;
    } else {
      warnings.add(ValidationWarning(
        code: 'TUNE_REV_LIMIT_UNSAFE',
        message:
            'Proposed rev limit ($proposedRevLimit RPM) exceeds '
            'safe mechanical limit (${model.maxSafeRevRaise} RPM).',
        isBlocking: true,
      ));
    }

    // --- Knock zone aggression check: +20 ---
    // Any positive timing advance applied while the model has known knock zones
    // counts as aggressive tuning in knock zones.
    final hasKnockZones = model.knockRpmZones.isNotEmpty;
    final timingIsPositive = profile.timingAdvanceDeg > 0;
    if (!hasKnockZones || !timingIsPositive) {
      score += 20;
    } else {
      warnings.add(ValidationWarning(
        code: 'TUNE_KNOCK_ZONE_AGGRESSION',
        message:
            'Timing advance of ${profile.timingAdvanceDeg}° is applied '
            'while this model has known knock-prone RPM zones: '
            '${model.knockRpmZones.join(', ')} RPM. '
            'Monitor closely for knock.',
        isBlocking: false,
      ));
    }

    // Clamp score: 0-100
    score = score.clamp(0, 100);

    // Backup warning — always required
    if (!backupConfirmed) {
      warnings.add(const ValidationWarning(
        code: 'TUNE_NO_BACKUP',
        message:
            'ECU backup not confirmed. A backup MUST be taken before '
            'any remap operation.',
        isBlocking: true,
      ));
    }

    final vvaWarning = requiresVvaWarning(model: model, profile: profile);
    if (vvaWarning) {
      warnings.add(ValidationWarning(
        code: 'TUNE_VVA_ZONE_WARNING',
        message:
            'This model has VVA (variable valve actuation) that transitions '
            'around ${model.vvaTransitionRpm} RPM. The timing advance of '
            '${profile.timingAdvanceDeg}° (> 1°) requires extra care in '
            'the 5800-6200 RPM zone.',
        isBlocking: false,
      ));
    }

    final level = _levelFromScore(score);

    return SafetyValidationResult(
      score: score,
      level: level,
      warnings: warnings,
      vvaZoneWarningRequired: vvaWarning,
      backupRequired: !backupConfirmed,
    );
  }

  // ---------------------------------------------------------------------------
  // VVA ZONE CHECK
  //
  // Any timing change > +1° in 5800-6200 RPM zone → mandatory warning.
  // ---------------------------------------------------------------------------

  /// Returns true when a VVA zone warning must be displayed.
  /// Condition: model has VVA AND profile timing advance > 1°.
  static bool requiresVvaWarning({
    required MotorcycleModel model,
    required TuneProfile profile,
  }) {
    if (!model.hasVva) return false;
    return profile.timingAdvanceDeg > 1;
  }

  /// Returns true when [profile] is compatible with [model].
  /// A profile is incompatible when:
  ///  - The model lacks a required engine feature (e.g., profile needs VVA but bike has none)
  ///  - The model has a feature the profile explicitly forbids
  ///  - The model displacement is outside the profile's allowed range
  static bool isProfileCompatible(MotorcycleModel model, TuneProfile profile) {
    final modelFeatures = _featuresOf(model);

    // All required features must be present on the model
    for (final req in profile.requiredFeatures) {
      if (!modelFeatures.contains(req)) return false;
    }

    // No incompatible features may be present on the model
    for (final inc in profile.incompatibleWith) {
      if (modelFeatures.contains(inc)) return false;
    }

    // Displacement bounds
    if (profile.minDisplacementCc > 0 &&
        model.displacement < profile.minDisplacementCc) return false;
    if (profile.maxDisplacementCc < 9999 &&
        model.displacement > profile.maxDisplacementCc) return false;

    return true;
  }

  static Set<EngineFeature> _featuresOf(MotorcycleModel model) {
    final features = <EngineFeature>{};
    if (model.hasVva) features.add(EngineFeature.vva);
    if (model.valveSystem.toUpperCase().contains('DOHC')) {
      features.add(EngineFeature.dohc);
    } else {
      features.add(EngineFeature.sohc);
    }
    features.add(EngineFeature.fuelInjected); // all seeded bikes are FI
    if (model.cooling == 'liquid') {
      features.add(EngineFeature.liquidCooled);
    } else {
      features.add(EngineFeature.airCooled);
    }
    if (model.displacement > 150) features.add(EngineFeature.displacement150Plus);
    if (model.displacement > 300) features.add(EngineFeature.displacement300Plus);
    return features;
  }

  // ---------------------------------------------------------------------------
  // INDIVIDUAL VALIDATION HELPERS
  // ---------------------------------------------------------------------------

  /// Validate a single AFR value against the model's safe range.
  static bool isAfrSafe(double afr, MotorcycleModel model) {
    return afr >= model.safeAfrMin && afr <= model.safeAfrMax;
  }

  /// Validate timing advance against the compression-derived floor.
  ///
  /// SAFETY FLOOR — ALWAYS use this; never trust admin input directly.
  /// model.maxTimingAdvance is derived from compressionRatio:
  ///   >= 11.5:1 → max +3°
  ///   >= 11.0:1 → max +4°
  ///   <  11.0:1 → max +5°
  static bool isTimingAdvanceSafe(int advanceDeg, MotorcycleModel model) {
    return advanceDeg <= model.maxTimingAdvance;
  }

  /// Validate a proposed absolute rev limit against the model's safe maximum.
  static bool isRevLimitSafe(int proposedRevLimit, MotorcycleModel model) {
    return proposedRevLimit <= model.maxSafeRevRaise;
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  /// Convert a numeric score to a SafetyLevel.
  ///   >= 85  → approved
  ///   70-84  → warning
  ///   < 70   → hardLock
  static SafetyLevel _levelFromScore(int score) {
    if (score >= 85) return SafetyLevel.approved;
    if (score >= 70) return SafetyLevel.warning;
    return SafetyLevel.hardLock;
  }
}
