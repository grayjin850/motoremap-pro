import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/obd_commands.dart';
import 'bluetooth_service.dart';

// ---------------------------------------------------------------------------
// OBD reading value object
// ---------------------------------------------------------------------------

class OBDReading {
  /// Engine RPM. Null when NODATA or parse failure.
  final int? rpm;

  /// Throttle position sensor, 0-100%. Null when NODATA.
  final double? tpsPercent;

  /// Coolant temperature in °C. Null when NODATA.
  final int? coolantTempC;

  /// Battery voltage in Volts. Null when NODATA.
  final double? batteryVoltage;

  /// Narrowband O2 sensor voltage, 0-1.275V.
  /// NOTE: This is the raw narrowband O2 voltage, NOT AFR.
  /// Use AfrCalculator.fromO2Voltage() to estimate AFR separately.
  final double? o2SensorVoltage;

  /// MAP sensor reading in kPa. Null when NODATA.
  final int? mapKpa;

  /// Timestamp of when this reading was captured.
  final DateTime timestamp;

  const OBDReading({
    this.rpm,
    this.tpsPercent,
    this.coolantTempC,
    this.batteryVoltage,
    this.o2SensorVoltage,
    this.mapKpa,
    required this.timestamp,
  });

  /// True if at least one PID returned valid data.
  bool get hasAnyData =>
      rpm != null ||
      tpsPercent != null ||
      coolantTempC != null ||
      batteryVoltage != null ||
      o2SensorVoltage != null ||
      mapKpa != null;

  /// Empty reading for error/fallback states.
  factory OBDReading.empty() => OBDReading(timestamp: DateTime.now());

  @override
  String toString() =>
      'OBDReading(rpm=$rpm, tps=$tpsPercent, temp=$coolantTempC, '
      'batt=$batteryVoltage, o2=$o2SensorVoltage, map=$mapKpa)';
}

// ---------------------------------------------------------------------------
// OBDService
// ---------------------------------------------------------------------------

class OBDService {
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  bool get isInitialized => _initialized;

  /// Initialize the ELM327 adapter.
  ///
  /// Sends the standard init sequence: ATZ, ATE0, ATL0, ATH0, ATSP0.
  /// Returns false immediately if any command does not respond with 'OK'
  /// (ATZ is special — it returns a version string, not 'OK').
  Future<bool> initialize(BluetoothService bluetooth) async {
    _initialized = false;

    for (final cmd in ObdCommands.initSequence) {
      final response = await bluetooth.sendCommand(
        cmd,
        timeout: const Duration(seconds: 5),
      );

      if (response == null) {
        return false;
      }

      final cleaned = response.trim().toUpperCase();

      if (cmd == ObdCommands.reset) {
        // ATZ returns version string (e.g. "ELM327 v2.1"), not "OK"
        if (!cleaned.contains('ELM')) {
          // Lenient: accept any non-error response for ATZ
          if (cleaned.contains('ERROR') || cleaned.isEmpty) {
            return false;
          }
        }
      } else {
        // All other init commands must return OK
        if (!cleaned.contains(ObdCommands.ok)) {
          return false;
        }
      }
    }

    _initialized = true;
    return true;
  }

  /// Poll all available PIDs once and return an [OBDReading].
  ///
  /// Each PID is polled sequentially. NODATA on any PID results in a null
  /// field in the reading — the method never throws on data errors.
  Future<OBDReading> pollOnce(BluetoothService bluetooth) async {
    if (!_initialized) return OBDReading.empty();

    // Poll each PID sequentially — ELM327 does not support concurrent requests
    final rpmResp = await bluetooth.sendCommand(ObdCommands.rpm);
    final tpsResp = await bluetooth.sendCommand(ObdCommands.throttlePosition);
    final tempResp = await bluetooth.sendCommand(ObdCommands.coolantTemp);
    final battResp = await bluetooth.sendCommand(ObdCommands.batteryVoltage);
    final o2Resp = await bluetooth.sendCommand(ObdCommands.o2Sensor);
    final mapResp = await bluetooth.sendCommand(ObdCommands.mapSensor);

    return OBDReading(
      rpm: rpmResp != null ? _parseRpm(rpmResp) : null,
      tpsPercent: tpsResp != null ? _parseTps(tpsResp) : null,
      coolantTempC: tempResp != null ? _parseCoolantTemp(tempResp) : null,
      batteryVoltage: battResp != null ? _parseBatteryVoltage(battResp) : null,
      o2SensorVoltage: o2Resp != null ? _parseO2Voltage(o2Resp) : null,
      mapKpa: mapResp != null ? _parseMap(mapResp) : null,
      timestamp: DateTime.now(),
    );
  }

  /// Start continuous 500ms polling — returns a broadcast [Stream<OBDReading>].
  ///
  /// The stream uses [asyncMap] to prevent overlapping polls if a poll cycle
  /// takes longer than 500ms (e.g., slow adapter or many NODATA retries).
  Stream<OBDReading> startPolling(BluetoothService bluetooth) {
    return Stream.periodic(
      const Duration(milliseconds: 500),
      (_) => pollOnce(bluetooth),
    ).asyncMap((future) => future);
  }

  // ---------------------------------------------------------------------------
  // Private — ELM327 response parsers (one per PID type)
  // Each returns null on NODATA, ERROR, or any parse failure.
  // ---------------------------------------------------------------------------

  /// Parse RPM from ELM327 response.
  /// Formula: ((A * 256) + B) / 4
  /// Example: "410C1AF8" → A=0x1A=26, B=0xF8=248, (26*256+248)/4 = 1726 RPM
  int? _parseRpm(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      // Strip response header "410C" then read 2 data bytes
      final data = _stripHeader(clean, '410C');
      if (data == null || data.length < 4) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      final b = int.parse(data.substring(2, 4), radix: 16);
      return ((a * 256) + b) ~/ 4;
    } catch (_) {
      return null;
    }
  }

  /// Parse throttle position sensor (0-100%).
  /// Formula: A * 100 / 255
  double? _parseTps(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '4111');
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return (a * 100.0) / 255.0;
    } catch (_) {
      return null;
    }
  }

  /// Parse coolant temperature in °C.
  /// Formula: A - 40
  int? _parseCoolantTemp(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '4105');
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return a - 40;
    } catch (_) {
      return null;
    }
  }

  /// Parse battery voltage from ATRV response.
  /// ATRV returns a string like "12.4V" — extract the float value.
  double? _parseBatteryVoltage(String response) {
    final trimmed = response.trim().toUpperCase();
    // Quick error check before stripping
    if (trimmed.contains('NODATA') ||
        trimmed.contains('ERROR') ||
        trimmed.isEmpty) {
      return null;
    }
    try {
      // Remove non-numeric characters except '.' (e.g., "12.4V\r\n>" → "12.4")
      final digits = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
      if (digits.isEmpty) return null;
      final v = double.parse(digits);
      // Sanity check: motorcycle battery voltage should be 8-16V
      if (v < 8.0 || v > 16.0) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  /// Parse narrowband O2 sensor voltage (PID 0114).
  /// Formula: A * 0.005 (range: 0.00–1.275V)
  /// NOTE: This is a narrowband O2 reading, NOT AFR. Use AfrCalculator for AFR estimation.
  double? _parseO2Voltage(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '4114');
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return a * 0.005;
    } catch (_) {
      return null;
    }
  }

  /// Parse MAP sensor reading in kPa.
  /// Formula: A (raw byte value = kPa directly)
  int? _parseMap(String response) {
    final clean = _cleanResponse(response);
    if (clean == null) return null;
    try {
      final data = _stripHeader(clean, '410B');
      if (data == null || data.length < 2) return null;
      final a = int.parse(data.substring(0, 2), radix: 16);
      return a; // kPa, 0-255
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private — response cleaning utilities
  // ---------------------------------------------------------------------------

  /// Strip whitespace and check for ELM327 error sentinel strings.
  /// Returns null if the response is an error or empty; returns the
  /// cleaned, uppercased, whitespace-free hex string otherwise.
  String? _cleanResponse(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (trimmed.isEmpty ||
        trimmed.contains(ObdCommands.noData.replaceAll(' ', '')) ||
        trimmed.contains('NODATA') ||
        trimmed.contains('ERROR') ||
        trimmed.contains('NORESPONSE') ||
        trimmed.contains('SEARCHING') ||
        trimmed.contains('STOPPED') ||
        trimmed.contains('UNABLE')) {
      return null;
    }
    // Strip trailing '>' prompt character if present
    return trimmed.replaceAll('>', '');
  }

  /// Strip a known response header (e.g., "410C") from a cleaned hex string.
  /// Returns the remaining data bytes, or null if the header is not found.
  String? _stripHeader(String clean, String header) {
    final idx = clean.indexOf(header);
    if (idx == -1) return null;
    final after = clean.substring(idx + header.length);
    return after.isEmpty ? null : after;
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final obdServiceProvider = Provider<OBDService>((ref) => OBDService());

final obdReadingProvider = StreamProvider<OBDReading>((ref) {
  final obd = ref.watch(obdServiceProvider);
  final bluetooth = ref.watch(bluetoothServiceProvider);
  return obd.startPolling(bluetooth);
});
