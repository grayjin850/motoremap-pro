import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/obd_commands.dart';
import '../core/protocols/adapter_interface.dart';
import 'bluetooth_service.dart';

// ---------------------------------------------------------------------------
// OBDReading — extended data model
// ---------------------------------------------------------------------------

/// Snapshot of all OBD-II sensor readings from a single poll cycle.
///
/// Every field is nullable — null means the PID returned NODATA, an error,
/// or the ECU simply does not support that sensor.
class OBDReading {
  // --- Core engine sensors ---
  final int? rpm;
  final double? tpsPercent;
  final int? coolantTempC;
  final double? batteryVoltage;

  // --- Fuel / air sensors ---
  /// Raw narrowband O2 sensor voltage (0–1.275V). Use [AfrCalculator] for AFR.
  final double? o2SensorVoltage;
  final int? mapKpa;

  // --- Extended Phase 1 PIDs ---

  /// Intake air temperature in °C. Important for altitude/cold-weather tuning.
  final int? intakeAirTempC;

  /// Calculated engine load, 0–100%. Useful for load-axis tracing on fuel maps.
  final double? engineLoadPercent;

  /// Short-term fuel trim bank 1 in %. Positive = lean (ECU adding fuel).
  final double? fuelTrimShortTermPct;

  /// Long-term fuel trim bank 1 in %. Persistent correction stored in ECU.
  final double? fuelTrimLongTermPct;

  /// Fuel rail pressure in kPa.
  final double? fuelPressureKpa;

  // --- Knock detection ---
  /// Knock retard in degrees (PID 01A6 — spark advance).
  /// >0° means the ECU is pulling timing to prevent detonation.
  /// Null = ECU doesn't support this PID (most motorcycle ECUs).
  final double? knockRetardDeg;

  final DateTime timestamp;

  const OBDReading({
    this.rpm,
    this.tpsPercent,
    this.coolantTempC,
    this.batteryVoltage,
    this.o2SensorVoltage,
    this.mapKpa,
    this.intakeAirTempC,
    this.engineLoadPercent,
    this.fuelTrimShortTermPct,
    this.fuelTrimLongTermPct,
    this.fuelPressureKpa,
    this.knockRetardDeg,
    required this.timestamp,
  });

  /// True if at least one PID came back with valid data.
  bool get hasAnyData =>
      rpm != null ||
      tpsPercent != null ||
      coolantTempC != null ||
      batteryVoltage != null ||
      o2SensorVoltage != null ||
      mapKpa != null;

  /// True when the ECU is actively retarding timing (knock event).
  bool get isKnocking => (knockRetardDeg ?? 0) > 0;

  /// Combined fuel trim: short-term + long-term.
  double? get totalFuelTrimPct {
    if (fuelTrimShortTermPct == null && fuelTrimLongTermPct == null) return null;
    return (fuelTrimShortTermPct ?? 0) + (fuelTrimLongTermPct ?? 0);
  }

  factory OBDReading.empty() => OBDReading(timestamp: DateTime.now());

  @override
  String toString() =>
      'OBDReading(rpm=$rpm, tps=${tpsPercent?.toStringAsFixed(1)}%, '
      'coolant=${coolantTempC}°C, batt=${batteryVoltage}V, '
      'iat=${intakeAirTempC}°C, load=${engineLoadPercent?.toStringAsFixed(1)}%, '
      'stft=${fuelTrimShortTermPct?.toStringAsFixed(1)}%, '
      'knock=${knockRetardDeg?.toStringAsFixed(1)}°)';
}

// ---------------------------------------------------------------------------
// ECU Identification result
// ---------------------------------------------------------------------------

class EcuIdentification {
  final String? vin;
  final String? calibrationId;
  final String? partNumber;
  final String? detectedProtocol;

  const EcuIdentification({
    this.vin,
    this.calibrationId,
    this.partNumber,
    this.detectedProtocol,
  });

  bool get hasAnyData => vin != null || calibrationId != null || partNumber != null;
}

// ---------------------------------------------------------------------------
// OBDService
// ---------------------------------------------------------------------------

class OBDService {
  bool _initialized = false;
  AdapterInterface? _adapter;

  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the adapter and send the ELM327 startup sequence.
  ///
  /// [adapter] is the [AdapterInterface] to use (real or mock).
  /// Returns false if any init command fails.
  Future<bool> initialize(AdapterInterface adapter) async {
    _initialized = false;
    _adapter = adapter;

    for (final cmd in ObdCommands.initSequence) {
      final response = await adapter.sendCommand(
        cmd,
        timeout: const Duration(seconds: 5),
      );
      if (response == null) return false;

      final cleaned = response.trim().toUpperCase();
      if (cmd == ObdCommands.reset) {
        if (cleaned.contains('ERROR') || cleaned.isEmpty) return false;
      } else {
        if (!cleaned.contains(ObdCommands.ok)) return false;
      }
    }

    _initialized = true;
    return true;
  }

  // ---------------------------------------------------------------------------
  // ECU Identification (Mode 09)
  // ---------------------------------------------------------------------------

  /// Attempt to read ECU identification data (VIN, calibration ID, part number).
  ///
  /// Many motorcycle ECUs return NODATA for Mode 09. Always null-safe.
  Future<EcuIdentification> identifyEcu() async {
    if (_adapter == null || !_initialized) {
      return const EcuIdentification();
    }

    final vinResp = await _adapter!.sendCommand(ObdCommands.vin);
    final calResp = await _adapter!.sendCommand(ObdCommands.calibrationId);
    final pnResp  = await _adapter!.sendCommand(ObdCommands.ecuPartNumber);

    return EcuIdentification(
      vin:           _parseAsciiResponse(vinResp, '4902'),
      calibrationId: _parseAsciiResponse(calResp, '4904'),
      partNumber:    _parseAsciiResponse(pnResp,  '4906'),
    );
  }

  // ---------------------------------------------------------------------------
  // Polling
  // ---------------------------------------------------------------------------

  /// Poll all available PIDs once and return a complete [OBDReading].
  Future<OBDReading> pollOnce() async {
    if (!_initialized || _adapter == null) return OBDReading.empty();
    final adapter = _adapter!;

    // Poll sequentially — ELM327 is single-threaded
    final rpmResp   = await adapter.sendCommand(ObdCommands.rpm);
    final tpsResp   = await adapter.sendCommand(ObdCommands.throttlePosition);
    final tempResp  = await adapter.sendCommand(ObdCommands.coolantTemp);
    final battResp  = await adapter.sendCommand(ObdCommands.batteryVoltage);
    final o2Resp    = await adapter.sendCommand(ObdCommands.o2Sensor);
    final mapResp   = await adapter.sendCommand(ObdCommands.mapSensor);
    final iatResp   = await adapter.sendCommand(ObdCommands.intakeAirTemp);
    final loadResp  = await adapter.sendCommand(ObdCommands.engineLoad);
    final stftResp  = await adapter.sendCommand(ObdCommands.fuelTrimShortTerm);
    final ltftResp  = await adapter.sendCommand(ObdCommands.fuelTrimLongTerm);
    final knockResp = await adapter.sendCommand(ObdCommands.knockRetard);
    final fpResp    = await adapter.sendCommand(ObdCommands.fuelPressure);

    return OBDReading(
      rpm:                   rpmResp   != null ? _parseRpm(rpmResp)              : null,
      tpsPercent:            tpsResp   != null ? _parsePercentA(tpsResp, '4111') : null,
      coolantTempC:          tempResp  != null ? _parseTemp(tempResp, '4105')    : null,
      batteryVoltage:        battResp  != null ? _parseBattery(battResp)         : null,
      o2SensorVoltage:       o2Resp    != null ? _parseO2Voltage(o2Resp)         : null,
      mapKpa:                mapResp   != null ? _parseMap(mapResp)              : null,
      intakeAirTempC:        iatResp   != null ? _parseTemp(iatResp, '410F')     : null,
      engineLoadPercent:     loadResp  != null ? _parsePercentA(loadResp, '4104'): null,
      fuelTrimShortTermPct:  stftResp  != null ? _parseFuelTrim(stftResp, '4106'): null,
      fuelTrimLongTermPct:   ltftResp  != null ? _parseFuelTrim(ltftResp, '4107'): null,
      knockRetardDeg:        knockResp != null ? _parseKnockRetard(knockResp)    : null,
      fuelPressureKpa:       fpResp    != null ? _parseFuelPressure(fpResp)      : null,
      timestamp: DateTime.now(),
    );
  }

  /// Start continuous 500ms polling — returns a broadcast [Stream<OBDReading>].
  Stream<OBDReading> startPolling() {
    return Stream.periodic(
      const Duration(milliseconds: 500),
      (_) => pollOnce(),
    ).asyncMap((future) => future);
  }

  // ---------------------------------------------------------------------------
  // Private parsers
  // ---------------------------------------------------------------------------

  String? _cleanResponse(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (trimmed.isEmpty ||
        trimmed.contains('NODATA') ||
        trimmed.contains('ERROR') ||
        trimmed.contains('NORESPONSE') ||
        trimmed.contains('SEARCHING') ||
        trimmed.contains('STOPPED') ||
        trimmed.contains('UNABLE')) {
      return null;
    }
    return trimmed.replaceAll('>', '');
  }

  String? _stripHeader(String clean, String header) {
    final idx = clean.indexOf(header);
    if (idx == -1) return null;
    final after = clean.substring(idx + header.length);
    return after.isEmpty ? null : after;
  }

  /// RPM: ((A * 256) + B) / 4
  int? _parseRpm(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '410C');
      if (data == null || data.length < 4) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      final b = int.parse(data.substring(2, 4), radix: 16);
      return ((a * 256) + b) ~/ 4;
    } catch (_) { return null; }
  }

  /// Generic percent: A * 100 / 255  (TPS, engine load)
  double? _parsePercentA(String response, String header) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, header);
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return (a * 100.0) / 255.0;
    } catch (_) { return null; }
  }

  /// Temperature (coolant, IAT): A - 40
  int? _parseTemp(String response, String header) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, header);
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return a - 40;
    } catch (_) { return null; }
  }

  /// Battery voltage from ATRV: "12.6V" → 12.6
  double? _parseBattery(String response) {
    final trimmed = response.trim().toUpperCase();
    if (trimmed.contains('NODATA') || trimmed.contains('ERROR') || trimmed.isEmpty) return null;
    try {
      final digits = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
      if (digits.isEmpty) return null;
      final v = double.parse(digits);
      return (v < 8.0 || v > 16.0) ? null : v;
    } catch (_) { return null; }
  }

  /// O2 sensor voltage: A * 0.005
  double? _parseO2Voltage(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '4114');
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return a * 0.005;
    } catch (_) { return null; }
  }

  /// MAP sensor: A (kPa)
  int? _parseMap(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '410B');
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return a;
    } catch (_) { return null; }
  }

  /// Fuel trim: (A - 128) * 100 / 128
  double? _parseFuelTrim(String response, String header) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, header);
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return (a - 128) * 100.0 / 128.0;
    } catch (_) { return null; }
  }

  /// Fuel pressure: A × 3 (kPa gauge pressure)
  double? _parseFuelPressure(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '410A');
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return a * 3.0;
    } catch (_) { return null; }
  }

  /// Knock retard from PID 01A6: (A - 128) / 2, returned as positive retard degrees
  double? _parseKnockRetard(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '41A6');
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      final advance = (a - 128) / 2.0;
      return advance < 0 ? advance.abs() : 0.0;
    } catch (_) { return null; }
  }

  /// Parse Mode 09 ASCII response (VIN, calibration ID, part number).
  String? _parseAsciiResponse(String? response, String header) {
    if (response == null) return null;
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, header);
      if (data == null || data.length < 2) return null;
      // Convert hex pairs to ASCII characters
      final buffer = StringBuffer();
      for (int i = 0; i + 1 < data.length; i += 2) {
        final code = int.parse(data.substring(i, i + 2), radix: 16);
        if (code > 0 && code < 128) buffer.writeCharCode(code);
      }
      final result = buffer.toString().trim();
      return result.isEmpty ? null : result;
    } catch (_) { return null; }
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final obdServiceProvider = Provider<OBDService>((ref) => OBDService());

final obdReadingProvider = StreamProvider<OBDReading>((ref) {
  final obd = ref.watch(obdServiceProvider);
  final bluetooth = ref.watch(bluetoothServiceProvider);

  // Auto-initialize with mock adapter in debug when no real adapter is connected
  final adapter = bluetooth.adapter;
  if (adapter != null && !obd.isInitialized) {
    obd.initialize(adapter);
  }

  return obd.startPolling();
});
