import 'package:flutter/foundation.dart';
import 'adapter_interface.dart';
import 'elm327_adapter.dart';
import 'mock_adapter.dart';

/// Preferred hardware adapter type selected by the user or auto-detected.
enum PreferredAdapter {
  /// ELM327-compatible Bluetooth Classic adapter (Vgate, OBDLink MX+, etc.)
  elm327Bluetooth,

  /// Development mock — no real hardware needed.
  mock,
  // Future: elm327Wifi, openPort2, kLineDirect
}

/// Manages creation and lifecycle of ECU communication adapters.
///
/// In debug builds, [createAdapter] defaults to [MockAdapter] so the app
/// runs without real OBD hardware attached. In release builds, it defaults
/// to [Elm327BluetoothAdapter]. The user can always override via settings.
class AdapterRegistry {
  AdapterRegistry._();

  /// Registered adapter type name strings (for persistence / display).
  static const Map<PreferredAdapter, String> adapterNames = {
    PreferredAdapter.elm327Bluetooth: 'ELM327 Bluetooth',
    PreferredAdapter.mock: 'Mock (Dev Only)',
  };

  /// Create an adapter instance for the given preference.
  ///
  /// In debug builds, always returns [MockAdapter] unless [forceMock] is false
  /// AND [preferred] is explicitly set to a real adapter type.
  static AdapterInterface createAdapter({
    PreferredAdapter preferred = PreferredAdapter.elm327Bluetooth,
    bool forceMock = false,
  }) {
    if (forceMock || (kDebugMode && preferred == PreferredAdapter.mock)) {
      return MockAdapter();
    }
    return switch (preferred) {
      PreferredAdapter.elm327Bluetooth => Elm327BluetoothAdapter(),
      PreferredAdapter.mock            => MockAdapter(),
    };
  }

  /// Returns true if the given adapter type requires real hardware.
  static bool requiresHardware(PreferredAdapter adapter) =>
      adapter != PreferredAdapter.mock;
}
