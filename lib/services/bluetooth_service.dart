import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../core/protocols/adapter_interface.dart';
import '../core/protocols/elm327_adapter.dart';
import '../core/protocols/mock_adapter.dart';
import '../core/protocols/adapter_registry.dart';

export '../core/protocols/adapter_interface.dart' show AdapterConnectionStatus;
export 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    show BluetoothDevice;

// ---------------------------------------------------------------------------
// BluetoothService
// ---------------------------------------------------------------------------

/// Manages the lifecycle of the active ECU communication adapter.
///
/// In debug builds the app automatically uses [MockAdapter] so developers
/// can run without real OBD hardware. On a physical device call
/// [scanForOBDAdapters] → user picks a device → [connectToDevice].
///
/// The active [AdapterInterface] is then passed to [OBDService.initialize].
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  AdapterInterface? _adapter;
  StreamSubscription<AdapterConnectionStatus>? _adapterStatusSub;

  final StreamController<AdapterConnectionStatus> _statusController =
      StreamController<AdapterConnectionStatus>.broadcast();
  AdapterConnectionStatus _status = AdapterConnectionStatus.disconnected;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  AdapterConnectionStatus get connectionStatus => _status;
  Stream<AdapterConnectionStatus> get statusStream => _statusController.stream;

  /// The currently active adapter. Null when not connected.
  AdapterInterface? get adapter => _adapter;

  bool get isConnected => _status == AdapterConnectionStatus.connected;

  /// Returns the display name of the currently active adapter, or null.
  String? get connectedAdapterName => _adapter?.adapterName;

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Scan for paired Bluetooth Classic devices that look like OBD adapters.
  ///
  /// In debug builds returns a fake list. On a real device returns paired
  /// devices whose names match OBD adapter naming patterns.
  Future<List<BluetoothDevice>> scanForOBDAdapters() async {
    _setStatus(AdapterConnectionStatus.scanning);
    await Future<void>.delayed(const Duration(seconds: 1));
    _setStatus(AdapterConnectionStatus.disconnected);

    if (kDebugMode) {
      return [
        // Fake entries so the UI shows something in the debugger
        const BluetoothDevice(name: 'Mock ELM327 (Dev)', address: '00:00:00:00:00:00'),
        const BluetoothDevice(name: 'OBDLink MX+', address: '00:1D:A5:68:98:8B'),
      ];
    }

    final paired = await Elm327BluetoothAdapter.getPairedDevices();
    // Show all paired devices; let the user identify their OBD adapter
    return paired;
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connect to a Bluetooth device by its MAC address.
  ///
  /// Uses [MockAdapter] in debug mode when the address is the mock sentinel.
  /// Otherwise creates a real [Elm327BluetoothAdapter].
  Future<bool> connectToDevice(BluetoothDevice device) async {
    await _disposeCurrentAdapter();

    final useMock = kDebugMode && device.address == '00:00:00:00:00:00';
    _adapter = useMock ? MockAdapter() : Elm327BluetoothAdapter();

    _adapterStatusSub = _adapter!.statusStream.listen(_setStatus);
    return _adapter!.connect(device.address);
  }

  /// Disconnect and clean up the current adapter.
  Future<void> disconnect() async {
    await _disposeCurrentAdapter();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _disposeCurrentAdapter() async {
    await _adapterStatusSub?.cancel();
    _adapterStatusSub = null;
    _adapter?.dispose();
    _adapter = null;
    _setStatus(AdapterConnectionStatus.disconnected);
  }

  void _setStatus(AdapterConnectionStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  void dispose() {
    _disposeCurrentAdapter();
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

final bluetoothStatusProvider = StreamProvider<AdapterConnectionStatus>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.statusStream;
});

/// Provides the active [AdapterInterface]. Null when no device is connected.
final activeAdapterProvider = Provider<AdapterInterface?>((ref) {
  ref.watch(bluetoothStatusProvider); // recompute when status changes
  return ref.watch(bluetoothServiceProvider).adapter;
});

/// For backwards compatibility — exposes adapter registry with mock for tests.
AdapterInterface createMockAdapter() =>
    AdapterRegistry.createAdapter(preferred: PreferredAdapter.mock);
