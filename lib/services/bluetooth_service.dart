// MOCK — replace with real BT implementation
//
// Note: flutter_bluetooth_serial (Classic Bluetooth / BR/EDR) is NOT in pubspec.yaml.
// This file provides the full public API surface that the rest of the app depends on.
// When a physical Android device is available, add flutter_bluetooth_serial to pubspec.yaml
// and replace the mock body below with real FlutterBluetoothSerial calls.
//
// Android 12+ limitation (when real impl is added): flutter_bluetooth_serial ^0.4.0 requires
// the legacy BLUETOOTH_CONNECT + BLUETOOTH_SCAN permissions and may not work on Android 12+
// without additional manifest flags. Consider migrating to flutter_bluetooth_classic or a
// custom platform channel once Android 12+ support is needed.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Enums & value types
// ---------------------------------------------------------------------------

enum BluetoothConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class BluetoothDevice {
  final String name;
  final String address;

  const BluetoothDevice({required this.name, required this.address});

  @override
  String toString() => 'BluetoothDevice($name @ $address)';
}

// ---------------------------------------------------------------------------
// BluetoothService — singleton, mock implementation
// ---------------------------------------------------------------------------

class BluetoothService {
  // Singleton
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // Status management
  BluetoothConnectionStatus _status = BluetoothConnectionStatus.disconnected;
  final StreamController<BluetoothConnectionStatus> _statusController =
      StreamController<BluetoothConnectionStatus>.broadcast();

  // Simulated connected device
  BluetoothDevice? _connectedDevice;

  // Command/response buffer for mock (simulates ELM327 responses)
  int _pollCount = 0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  BluetoothConnectionStatus get connectionStatus => _status;

  Stream<BluetoothConnectionStatus> get statusStream =>
      _statusController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Scan for nearby Bluetooth devices and return those that look like OBD adapters.
  /// MOCK: returns a pre-defined list of fake OBD adapters after a short delay.
  Future<List<BluetoothDevice>> scanForOBDAdapters() async {
    _setStatus(BluetoothConnectionStatus.scanning);
    // Simulate scan delay
    await Future<void>.delayed(const Duration(seconds: 2));
    _setStatus(BluetoothConnectionStatus.disconnected);

    // MOCK — in real impl, call FlutterBluetoothSerial.instance.getBondedDevices()
    // and filter with isLikelyOBDAdapter()
    return const [
      BluetoothDevice(name: 'OBD2-ELM327', address: '00:1D:A5:68:98:8B'),
      BluetoothDevice(name: 'VLINK OBD', address: '00:0D:18:00:00:12'),
      BluetoothDevice(name: 'ELM327 v2.1', address: '00:1D:A5:00:00:01'),
    ];
  }

  /// Connect to a specific OBD adapter.
  /// MOCK: always succeeds after a short delay.
  Future<bool> connect(BluetoothDevice device) async {
    _setStatus(BluetoothConnectionStatus.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // MOCK — in real impl:
    // final connection = await BluetoothConnection.toAddress(device.address);
    // store connection, return true on success, false on exception
    _connectedDevice = device;
    _pollCount = 0;
    _setStatus(BluetoothConnectionStatus.connected);
    return true;
  }

  /// Send a raw command to the ELM327 adapter and return the response string.
  /// Returns null on timeout or if not connected.
  /// MOCK: returns pre-scripted ELM327-style responses for development.
  Future<String?> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_status != BluetoothConnectionStatus.connected) return null;

    // Simulate I/O latency
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // MOCK — in real impl: write bytes to BluetoothConnection.output,
    // read from BluetoothConnection.input until '>' prompt, apply timeout.
    return _mockResponse(command);
  }

  /// Disconnect cleanly and reset state.
  Future<void> disconnect() async {
    // MOCK — in real impl: await _connection?.close()
    _connectedDevice = null;
    _pollCount = 0;
    _setStatus(BluetoothConnectionStatus.disconnected);
  }

  // ---------------------------------------------------------------------------
  // Helper — OBD adapter name filter
  // ---------------------------------------------------------------------------

  /// Returns true if the device name looks like an OBD/ELM327 adapter.
  bool isLikelyOBDAdapter(String name) {
    final lower = name.toLowerCase();
    return lower.contains('obd') ||
        lower.contains('elm') ||
        lower.contains('vlink') ||
        lower.contains('scan') ||
        lower.contains('diag');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _setStatus(BluetoothConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  /// Produces realistic ELM327 mock responses keyed by command.
  String _mockResponse(String command) {
    _pollCount++;
    // Vary RPM realistically over time (idle ~1000, climbs to ~5000 then back)
    final cyclePos = _pollCount % 40;
    final rpmRaw = 1000 + (cyclePos < 20 ? cyclePos * 200 : (40 - cyclePos) * 200);

    switch (command.toUpperCase().trim()) {
      case 'ATZ':
        return 'ELM327 v2.1\r\n>';
      case 'ATE0':
      case 'ATL0':
      case 'ATH0':
      case 'ATSP0':
        return 'OK\r\n>';
      case '0100':
        return '4100BE3EA813\r\n>';
      case '010C': // RPM
        // Encode rpmRaw back to ELM327 format: (rpmRaw * 4) split into two bytes
        final encoded = (rpmRaw * 4).round();
        final a = (encoded >> 8) & 0xFF;
        final b = encoded & 0xFF;
        return '410C${a.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}\r\n>';
      case '0111': // Throttle position
        // 20% throttle
        final tpsRaw = (20 * 255 ~/ 100);
        return '4111${tpsRaw.toRadixString(16).padLeft(2, '0').toUpperCase()}\r\n>';
      case '0105': // Coolant temp
        // 85°C → raw = 85 + 40 = 125
        return '410579\r\n>'; // 0x79 = 121 → 121-40 = 81°C
      case 'ATRV': // Battery voltage
        return '12.6V\r\n>';
      case '0114': // O2 sensor
        // 0.45V → raw = 0.45 / 0.005 = 90 = 0x5A
        return '41145A\r\n>';
      case '010B': // MAP sensor
        // 95 kPa
        return '41115F\r\n>'; // Note: '010B' response header would be '410B'
      default:
        return 'NODATA\r\n>';
    }
  }

  void dispose() {
    _statusController.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  ref.onDispose(service.dispose);
  return service;
});

final bluetoothStatusProvider = StreamProvider<BluetoothConnectionStatus>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.statusStream;
});
