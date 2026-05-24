import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_remap_app/core/safety/safety_validator.dart';
import 'package:motorcycle_remap_app/models/motorcycle_model.dart';
import 'package:motorcycle_remap_app/models/tune_profile.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// Aerox 155 VVA — high compression (11.5:1) → maxTimingAdvance = 3
/// stockRevLimitHard = 9000, maxSafeRevRaise = 9500
/// safeAfrMin = 12.5, safeAfrMax = 14.5
/// hasVva = true, vvaTransitionRpm = 6000
const _aeroxModel = MotorcycleModel(
  id: 'aerox_155_vva',
  brand: 'Yamaha',
  model: 'Aerox 155',
  yearFrom: 2021,
  yearTo: 0,
  variant: 'VVA',
  displacement: 155,
  compressionRatio: 11.5, // → maxTimingAdvance = 3
  bore: 58.0,
  stroke: 58.7,
  valveSystem: 'SOHC',
  valveCount: 4,
  hasVva: true,
  vvaTransitionRpm: 6000,
  cooling: 'liquid',
  ecuType: 'Yamaha YEC',
  flashTool: 'YEC Flash',
  stockRevLimitSoft: 8500,
  stockRevLimitHard: 9000,
  stockSpeedLimit: 130,
  safeAfrMid: 13.8,
  safeAfrWot: 13.2,
  safeAfrMin: 12.5,
  safeAfrMax: 14.5,
  maxSafeRevRaise: 9500, // absolute max RPM
  knockRpmZones: [],     // no knock zones → knock check always passes
  expectedSpeedByLevel: {},
);

/// Same as Aerox but WITH knock zones — so timing > 0 triggers knock warning
const _aeroxWithKnockZones = MotorcycleModel(
  id: 'aerox_155_knock',
  brand: 'Yamaha',
  model: 'Aerox 155',
  yearFrom: 2021,
  yearTo: 0,
  variant: 'VVA Knock',
  displacement: 155,
  compressionRatio: 11.5,
  bore: 58.0,
  stroke: 58.7,
  valveSystem: 'SOHC',
  valveCount: 4,
  hasVva: true,
  vvaTransitionRpm: 6000,
  cooling: 'liquid',
  ecuType: 'Yamaha YEC',
  flashTool: 'YEC Flash',
  stockRevLimitSoft: 8500,
  stockRevLimitHard: 9000,
  stockSpeedLimit: 130,
  safeAfrMid: 13.8,
  safeAfrWot: 13.2,
  safeAfrMin: 12.5,
  safeAfrMax: 14.5,
  maxSafeRevRaise: 9500,
  knockRpmZones: [5500, 7000],
  expectedSpeedByLevel: {},
);

/// Non-VVA model — low compression (10.0:1) → maxTimingAdvance = 5
const _nonVvaModel = MotorcycleModel(
  id: 'generic_125_no_vva',
  brand: 'Honda',
  model: 'Click 125',
  yearFrom: 2020,
  yearTo: 0,
  variant: 'Standard',
  displacement: 125,
  compressionRatio: 10.0, // → maxTimingAdvance = 5
  bore: 52.4,
  stroke: 57.9,
  valveSystem: 'SOHC',
  valveCount: 2,
  hasVva: false,
  vvaTransitionRpm: 0,
  cooling: 'air',
  ecuType: 'Honda PGM-FI',
  flashTool: 'KPRO',
  stockRevLimitSoft: 8000,
  stockRevLimitHard: 8500,
  stockSpeedLimit: 110,
  safeAfrMid: 13.8,
  safeAfrWot: 13.2,
  safeAfrMin: 12.5,
  safeAfrMax: 14.5,
  maxSafeRevRaise: 9000,
  knockRpmZones: [],
  expectedSpeedByLevel: {},
);

/// High-compression model (11.6:1) → maxTimingAdvance = 3
const _highCompressionModel = MotorcycleModel(
  id: 'high_comp_model',
  brand: 'Yamaha',
  model: 'NMAX 155',
  yearFrom: 2022,
  yearTo: 0,
  variant: 'Tech',
  displacement: 155,
  compressionRatio: 11.6, // >= 11.5 → maxTimingAdvance = 3
  bore: 58.0,
  stroke: 58.7,
  valveSystem: 'SOHC',
  valveCount: 4,
  hasVva: false,
  vvaTransitionRpm: 0,
  cooling: 'liquid',
  ecuType: 'Yamaha YEC',
  flashTool: 'YEC Flash',
  stockRevLimitSoft: 8500,
  stockRevLimitHard: 9000,
  stockSpeedLimit: 130,
  safeAfrMid: 13.8,
  safeAfrWot: 13.2,
  safeAfrMin: 12.5,
  safeAfrMax: 14.5,
  maxSafeRevRaise: 9500,
  knockRpmZones: [],
  expectedSpeedByLevel: {},
);

// ---------------------------------------------------------------------------
// Profile builder helper
// ---------------------------------------------------------------------------

TuneProfile _buildProfile({
  double afrMid = 13.8,
  double afrWot = 13.2,
  int timingAdvance = 2,
  int revLimitRaise = 0,
}) {
  return TuneProfile(
    id: 'test_profile',
    motorcycleModelId: 'aerox_155_vva',
    type: ProfileType.balanced,
    nameTaglish: 'Test Profile',
    descriptionTaglish: 'Test',
    afrTargetMid: afrMid,
    afrTargetWot: afrWot,
    timingAdvanceDeg: timingAdvance,
    revLimitRaise: revLimitRaise,
    removeSpeedLimiter: false,
    safetyScore: 0,
    expectedBenefits: '',
    fuelConsumptionNote: '',
    fuelMapJson: '[]',
    ignitionMapJson: '[]',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SafetyValidator — calculatePreRemapScore', () {
    test('1. Perfect score: 0 faults, warmed up, all checked, backup → 100 approved', () {
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 0,
        engineWarmedUp: true,
        uncheckedChecklistItems: 0,
        backupConfirmed: true,
      );
      expect(result.score, equals(100));
      expect(result.level, equals(SafetyLevel.approved));
      expect(result.canGenerateReferenceSheet, isTrue);
    });

    test('2. One fault code: score = 80, level = warning', () {
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 1,
        engineWarmedUp: true,
        uncheckedChecklistItems: 0,
        backupConfirmed: true,
      );
      expect(result.score, equals(80));
      expect(result.level, equals(SafetyLevel.warning));
    });

    test('3. Three fault codes: score = 40, level = hardLock', () {
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 3,
        engineWarmedUp: true,
        uncheckedChecklistItems: 0,
        backupConfirmed: true,
      );
      expect(result.score, equals(40));
      expect(result.level, equals(SafetyLevel.hardLock));
    });

    test('4. Cold engine only: score = 85, level = approved (boundary)', () {
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 0,
        engineWarmedUp: false,
        uncheckedChecklistItems: 0,
        backupConfirmed: true,
      );
      expect(result.score, equals(85));
      expect(result.level, equals(SafetyLevel.approved));
    });

    test('5. Cold engine + 1 fault code: score = 65, level = hardLock', () {
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 1,
        engineWarmedUp: false,
        uncheckedChecklistItems: 0,
        backupConfirmed: true,
      );
      // 100 - 20 (fault) - 15 (cold) = 65
      expect(result.score, equals(65));
      expect(result.level, equals(SafetyLevel.hardLock));
    });

    test('6. Score never negative: 10 faults + cold + all 7 unchecked → 0', () {
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 10,
        engineWarmedUp: false,
        uncheckedChecklistItems: 7,
        backupConfirmed: true,
      );
      // 100 - 200 - 15 - 70 = -185 → clamped to 0
      expect(result.score, equals(0));
      expect(result.level, equals(SafetyLevel.hardLock));
    });

    test('7. All 7 items unchecked: score = 30, level = hardLock', () {
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 0,
        engineWarmedUp: true,
        uncheckedChecklistItems: 7,
        backupConfirmed: true,
      );
      // 100 - 70 = 30
      expect(result.score, equals(30));
      expect(result.level, equals(SafetyLevel.hardLock));
    });

    test('8. Backup not confirmed → canGenerateReferenceSheet = false', () {
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 0,
        engineWarmedUp: true,
        uncheckedChecklistItems: 0,
        backupConfirmed: false, // no backup
      );
      // Score = 100, level = approved — but backup missing
      expect(result.score, equals(100));
      expect(result.level, equals(SafetyLevel.approved));
      expect(result.canGenerateReferenceSheet, isFalse);
    });

    test('9. Score 84 → level = warning (boundary)', () {
      // 100 - 1 fault (20) - unchecked(0) - cold(15) - but we need exactly 84
      // 100 - 16 = 84? We don't have fractional deductions.
      // Use cold (-15) + 1 unchecked item (-10) = -25 → 75 (too low)
      // We can't get 84 with integer deductions. Use 1 fault = -20 → 80 (not 84).
      // Use cold (-15) + 0 = 85 → that's approved.
      // Actually we can't achieve exactly 84 with the deduction rules (-20, -15, -10 each).
      // The boundary test should test a score that we can achieve near 84.
      // Closest below 85 we can get: cold (-15) = 85, cold + 1 item = 75.
      // So we test 80 (1 fault code) which is in warning range.
      // REVISED: test that score in [70, 84] → warning. 80 is warning.
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 1, // -20 → score = 80
        engineWarmedUp: true,
        uncheckedChecklistItems: 0,
        backupConfirmed: true,
      );
      expect(result.score, equals(80));
      expect(result.level, equals(SafetyLevel.warning));
    });

    test('10. Score 70 → level = warning (boundary)', () {
      // 100 - 20 (1 fault) - 10 (1 item) = 70
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 1,
        engineWarmedUp: true,
        uncheckedChecklistItems: 1,
        backupConfirmed: true,
      );
      expect(result.score, equals(70));
      expect(result.level, equals(SafetyLevel.warning));
    });

    test('11. Score 69 → level = hardLock (boundary)', () {
      // 100 - 20 (1 fault) - 15 (cold) - 10 (1 unchecked) = 55 (too low)
      // 100 - 20 - 10 - 1*10 = 70 (warning)
      // 100 - 20 - 10 - 15 = 55 ... can't get 69 exactly
      // 100 - 20 (fault) - 15 (cold) = 65 < 70 → hardLock
      // Closest to 69: 100 - 20 - 10 (1 unchecked item) = 70 → warning.
      // 100 - 20 - 20 = 60 → hardLock. Can't hit 69 exactly.
      // Test the boundary by testing cold+fault (65) is hardLock
      // and 1 fault + 1 unchecked (70) is warning (already covered above).
      // So document: any score < 70 is hardLock. 65 is hardLock.
      final result = SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: 1,
        engineWarmedUp: false, // -15
        uncheckedChecklistItems: 0,
        backupConfirmed: true,
      );
      // 100 - 20 - 15 = 65 → hardLock (65 < 70)
      expect(result.score, equals(65));
      expect(result.level, equals(SafetyLevel.hardLock));
    });
  });

  // -------------------------------------------------------------------------
  // calculateTuneSafetyScore
  // -------------------------------------------------------------------------

  group('SafetyValidator — calculateTuneSafetyScore', () {
    test('12. All conditions met → score = 100, level = approved', () {
      // _aeroxModel: compressionRatio=11.5 → maxTimingAdvance=3
      // safeAfrMin=12.5, safeAfrMax=14.5
      // stockRevLimitHard=9000, maxSafeRevRaise=9500
      // knockRpmZones=[] → knock check passes
      final profile = _buildProfile(
        afrMid: 13.8,   // in [12.5, 14.5] ✓
        afrWot: 13.2,   // in [12.5, 14.5] ✓
        timingAdvance: 2, // 2 <= 3 ✓
        revLimitRaise: 0, // 9000 + 0 = 9000 <= 9500 ✓
      );
      final result = SafetyValidator.calculateTuneSafetyScore(
        model: _aeroxModel,
        profile: profile,
        backupConfirmed: true,
      );
      // +30 AFR + +30 timing + +20 rev + +20 no-knock = 100
      expect(result.score, equals(100));
      expect(result.level, equals(SafetyLevel.approved));
    });

    test('13. AFR outside safe range → score = 70, level = warning', () {
      // afrMid = 11.0 (< 12.5, outside safe range) → AFR check fails → no +30
      final profile = _buildProfile(
        afrMid: 11.0,   // < 12.5, outside safe range
        afrWot: 13.2,   // ok
        timingAdvance: 2, // 2 <= 3 ✓
        revLimitRaise: 0, // 9000 <= 9500 ✓
      );
      final result = SafetyValidator.calculateTuneSafetyScore(
        model: _aeroxModel,
        profile: profile,
        backupConfirmed: true,
      );
      // +0 (AFR fail) + +30 timing + +20 rev + +20 no-knock = 70
      expect(result.score, equals(70));
      expect(result.level, equals(SafetyLevel.warning));
    });

    test('14. Timing advance exceeds compression-derived limit → score = 70, level = warning', () {
      // _aeroxModel: maxTimingAdvance = 3, use timingAdvance = 4 → fails
      final profile = _buildProfile(
        afrMid: 13.8,
        afrWot: 13.2,
        timingAdvance: 4, // 4 > 3 → timing check fails
        revLimitRaise: 0,
      );
      final result = SafetyValidator.calculateTuneSafetyScore(
        model: _aeroxModel,
        profile: profile,
        backupConfirmed: true,
      );
      // +30 AFR + +0 timing fail + +20 rev + +20 no-knock = 70
      expect(result.score, equals(70));
      expect(result.level, equals(SafetyLevel.warning));
    });

    test('15. Rev limit exceeds maxSafeRevRaise → score = 80, level = warning', () {
      // _aeroxModel: stockRevLimitHard=9000, maxSafeRevRaise=9500
      // revLimitRaise=600 → proposed=9600 > 9500 → fails
      final profile = _buildProfile(
        afrMid: 13.8,
        afrWot: 13.2,
        timingAdvance: 2, // ok
        revLimitRaise: 600, // 9000+600=9600 > 9500 → rev check fails
      );
      final result = SafetyValidator.calculateTuneSafetyScore(
        model: _aeroxModel,
        profile: profile,
        backupConfirmed: true,
      );
      // +30 AFR + +30 timing + +0 rev fail + +20 no-knock = 80
      expect(result.score, equals(80));
      expect(result.level, equals(SafetyLevel.warning));
    });

    test('16. High-compression (11.6:1 → max +3°): timingAdvanceDeg=4 → timing fails', () {
      // _highCompressionModel: compressionRatio=11.6 → maxTimingAdvance=3
      expect(_highCompressionModel.maxTimingAdvance, equals(3));

      final profile = _buildProfile(
        afrMid: 13.8,
        afrWot: 13.2,
        timingAdvance: 4, // 4 > 3 → fails
        revLimitRaise: 0,
      );
      final result = SafetyValidator.calculateTuneSafetyScore(
        model: _highCompressionModel,
        profile: profile,
        backupConfirmed: true,
      );
      expect(result.score, lessThan(100));
      expect(
        result.warnings.any((w) => w.code == 'TUNE_TIMING_UNSAFE'),
        isTrue,
      );
    });

    test('17. Low-compression (10.0:1 → max +5°): timingAdvanceDeg=4 → timing passes', () {
      // _nonVvaModel: compressionRatio=10.0 → maxTimingAdvance=5
      expect(_nonVvaModel.maxTimingAdvance, equals(5));

      final profile = _buildProfile(
        afrMid: 13.8,
        afrWot: 13.2,
        timingAdvance: 4, // 4 <= 5 → passes
        revLimitRaise: 0,
      );
      final result = SafetyValidator.calculateTuneSafetyScore(
        model: _nonVvaModel,
        profile: profile,
        backupConfirmed: true,
      );
      expect(
        result.warnings.any((w) => w.code == 'TUNE_TIMING_UNSAFE'),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // requiresVvaWarning
  // -------------------------------------------------------------------------

  group('SafetyValidator — requiresVvaWarning', () {
    test('18. VVA model + timingAdvanceDeg > 1 → true', () {
      final profile = _buildProfile(timingAdvance: 2); // > 1
      expect(
        SafetyValidator.requiresVvaWarning(model: _aeroxModel, profile: profile),
        isTrue,
      );
    });

    test('19. VVA model + timingAdvanceDeg = 1 → false', () {
      final profile = _buildProfile(timingAdvance: 1); // = 1, not > 1
      expect(
        SafetyValidator.requiresVvaWarning(model: _aeroxModel, profile: profile),
        isFalse,
      );
    });

    test('20. Non-VVA model + any timing → false', () {
      final profile = _buildProfile(timingAdvance: 5); // high timing, but no VVA
      expect(
        SafetyValidator.requiresVvaWarning(model: _nonVvaModel, profile: profile),
        isFalse,
      );
    });
  });

  group('SafetyValidator — calculateTuneSafetyScore knock zone check', () {
    test('21. Model with knock zones + positive timing → KNOCK_ZONE_AGGRESSION warning, -20 pts', () {
      final profile = _buildProfile(timingAdvance: 2); // positive timing
      final result = SafetyValidator.calculateTuneSafetyScore(
        model: _aeroxWithKnockZones,
        profile: profile,
        backupConfirmed: true,
      );
      // AFR safe (+30), timing safe for 11.5:1 at +2° (+30), rev safe (+20), knock zone fail (+0)
      expect(result.score, equals(80));
      expect(result.level, equals(SafetyLevel.warning));
      expect(
        result.warnings.any((w) => w.code == 'TUNE_KNOCK_ZONE_AGGRESSION'),
        isTrue,
      );
    });

    test('22. Model with knock zones + zero timing → knock zone check passes, full score', () {
      final profile = _buildProfile(timingAdvance: 0); // no timing advance
      final result = SafetyValidator.calculateTuneSafetyScore(
        model: _aeroxWithKnockZones,
        profile: profile,
        backupConfirmed: true,
      );
      // AFR safe (+30), timing safe (+30), rev safe (+20), knock zone safe (+20) = 100
      expect(result.score, equals(100));
      expect(result.level, equals(SafetyLevel.approved));
      expect(
        result.warnings.any((w) => w.code == 'TUNE_KNOCK_ZONE_AGGRESSION'),
        isFalse,
      );
    });
  });
}
