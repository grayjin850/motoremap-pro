import 'dart:typed_data';
import '../binary/checksum_engine.dart';
import '../ecu/ecu_definition.dart';

/// Result of a single pre-flash safety check.
class GateCheck {
  final String label;
  final bool passed;
  final String detail;

  /// Advisory checks show as warnings but do NOT block the flash.
  /// All non-advisory (blocking) checks must pass for [allGreen] to be true.
  final bool isAdvisory;

  const GateCheck({
    required this.label,
    required this.passed,
    required this.detail,
    this.isAdvisory = false,
  });
}

/// Result of the entire pre-flash gate evaluation.
class PreFlashGateResult {
  final List<GateCheck> checks;

  const PreFlashGateResult({required this.checks});

  /// True only when all BLOCKING (non-advisory) checks pass.
  bool get allGreen => checks.where((c) => !c.isAdvisory).every((c) => c.passed);

  int get safetyScore {
    if (checks.isEmpty) return 0;
    final passed = checks.where((c) => c.passed).length;
    return ((passed / checks.length) * 100).round();
  }

  List<GateCheck> get failedChecks => checks.where((c) => !c.passed).toList();
}

/// Pre-flash safety gate — ALL 8 conditions must be green before flashing.
///
/// Condition list:
///   1. Wired USB adapter (supportsWrite = true) — Bluetooth cannot flash
///   2. Battery ≥ 12.4V
///   3. RPM = 0 (engine stopped)
///   4. Coolant < 40°C (or air-cooled exemption)
///   5. Backup verified (backup file readable, size matches)
///   6. Checksum verified (modified ROM checksum is valid)
///   7. Diff approved (tuner explicitly approved the diff viewer)
///   8. Safety score ≥ 85 (at least 7 of 8 conditions met before this check)
class PreFlashGate {
  /// Evaluate all gate conditions.
  ///
  /// [adapterSupportsWrite] must be true only for wired USB K-Line adapters.
  ///   Bluetooth (ELM327) adapters always return false — they cannot flash.
  /// [batteryVoltage] from OBD live data (V).
  /// [engineRpm] from OBD live data.
  /// [coolantTempC] from OBD live data (-1 if unavailable / air-cooled ECU).
  /// [backupVerified] must be set to true by caller after successfully reading
  ///   back the original ROM and saving it.
  /// [modifiedRom] is the patched ROM that will be written.
  /// [ecu] used for checksum algorithm lookup.
  /// [diffApproved] must be true only after tuner checked the box in RomDiffViewer.
  /// [widebandConfirmed] advisory — true if mechanic has a wideband O2 sensor
  ///   to validate the tune after flashing. Does NOT block flash if false.
  static PreFlashGateResult evaluate({
    required bool adapterSupportsWrite,
    required double batteryVoltage,
    required int engineRpm,
    required double coolantTempC,
    required bool backupVerified,
    required Uint8List modifiedRom,
    required EcuDefinition ecu,
    required bool diffApproved,
    bool widebandConfirmed = false,
  }) {
    final checks = <GateCheck>[];

    // 1. Wired USB adapter required — Bluetooth (ELM327) cannot flash ECU ROM
    checks.add(GateCheck(
      label: 'Wired USB adapter connected (OpenPort 2.0 / K-Line)',
      passed: adapterSupportsWrite,
      detail: adapterSupportsWrite
          ? 'USB K-Line adapter confirmed — write capable'
          : 'BLOCKED: Bluetooth adapters cannot flash. '
            'Connect a wired USB K-Line adapter (OpenPort 2.0 or equivalent).',
    ));

    // 2. Battery
    checks.add(GateCheck(
      label: 'Battery voltage ≥ 12.4V',
      passed: batteryVoltage >= 12.4,
      detail: batteryVoltage < 0
          ? 'Could not read battery voltage'
          : '${batteryVoltage.toStringAsFixed(1)}V — '
              '${batteryVoltage >= 12.4 ? 'OK' : 'Too low — charge battery before flashing'}',
    ));

    // 2. Engine off
    checks.add(GateCheck(
      label: 'Engine stopped (RPM = 0)',
      passed: engineRpm == 0,
      detail: engineRpm == 0
          ? 'Engine is off'
          : 'RPM = $engineRpm — turn off engine before flashing',
    ));

    // 3. Coolant temperature (air-cooled ECUs pass automatically with coolantTempC = -1)
    final isAirCooled = coolantTempC < 0;
    checks.add(GateCheck(
      label: 'Coolant < 40°C (or air-cooled)',
      passed: isAirCooled || coolantTempC < 40,
      detail: isAirCooled
          ? 'Air-cooled engine — coolant check skipped'
          : '${coolantTempC.toStringAsFixed(0)}°C — '
              '${coolantTempC < 40 ? 'OK' : 'Engine too hot — wait for cooldown'}',
    ));

    // 4. Backup verified
    checks.add(GateCheck(
      label: 'Backup ROM saved and verified',
      passed: backupVerified,
      detail: backupVerified
          ? 'Backup confirmed'
          : 'Backup not verified — read ROM first',
    ));

    // 5. Checksum verified
    bool checksumOk = false;
    String checksumDetail = 'No checksum descriptor for this ECU';
    if (ecu.checksumDescriptor != null) {
      checksumOk = ChecksumEngine.verify(modifiedRom, ecu.checksumDescriptor!);
      checksumDetail = checksumOk
          ? 'ROM checksum valid'
          : 'ROM checksum invalid — apply checksum correction before flashing';
    } else {
      checksumOk = true; // no checksum = skip
    }
    checks.add(GateCheck(
      label: 'ROM checksum verified',
      passed: checksumOk,
      detail: checksumDetail,
    ));

    // 6. Diff approved
    checks.add(GateCheck(
      label: 'Diff reviewed and approved',
      passed: diffApproved,
      detail: diffApproved
          ? 'Tuner approved diff'
          : 'Open diff viewer and check the approval box before flashing',
    ));

    // 7. Safety score ≥ 85 (based on blocking checks 1–6 only)
    final blockingChecks = checks.where((c) => !c.isAdvisory).toList();
    final partialScore = blockingChecks.isEmpty
        ? 0
        : ((blockingChecks.where((c) => c.passed).length / blockingChecks.length) * 100).round();
    checks.add(GateCheck(
      label: 'Safety score ≥ 85',
      passed: partialScore >= 85,
      detail: 'Score: $partialScore / 100 — '
          '${partialScore >= 85 ? 'Sufficient' : 'Resolve failing checks above'}',
    ));

    // 8. Wideband O2 sensor advisory (NON-BLOCKING — does not prevent flash)
    //
    // The Bluetooth OBD AFR gauge is a NARROWBAND ESTIMATE only. It is accurate
    // at stoich (14.7:1) but unreliable at WOT or lean conditions. Post-flash
    // validation requires a wideband O2 sensor (Innovate LC-2, AEM X-Series,
    // PLX SM-AFR) to confirm the tune is actually safe under real load.
    checks.add(GateCheck(
      label: 'Wideband O2 sensor available (advisory)',
      passed: widebandConfirmed,
      detail: widebandConfirmed
          ? 'Wideband sensor ready — tune can be validated under load'
          : 'WARNING: No wideband sensor confirmed. '
            'The Bluetooth AFR gauge is a narrowband estimate — NOT accurate at WOT. '
            'Flash is allowed, but validate the tune on a dyno with a wideband sensor '
            'before returning the bike to the customer.',
      isAdvisory: true,
    ));

    return PreFlashGateResult(checks: checks);
  }
}
