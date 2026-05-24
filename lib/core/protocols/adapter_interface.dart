import 'dart:typed_data';

/// Connection state of any ECU communication adapter.
enum AdapterConnectionStatus { disconnected, scanning, connecting, connected, error }

/// Supported OBD/ECU communication protocols.
/// Used to configure the active protocol on an ELM327-compatible adapter.
enum OBDProtocol {
  auto,         // ATSP0 — let ELM327 detect
  can11bit,     // ATSP6 — ISO 15765-4 CAN 11-bit (most modern FI bikes)
  can29bit,     // ATSP7 — ISO 15765-4 CAN 29-bit
  kwp2000Fast,  // ATSP5 — ISO 14230-4 KWP2000 Fast Init (Honda/Yamaha/Suzuki FI)
  kwp2000Slow,  // ATSP4 — ISO 14230-4 KWP2000 Slow Init (older bikes)
  iso9141,      // ATSP3 — ISO 9141-2 legacy
}

extension OBDProtocolExt on OBDProtocol {
  String get atCommand => switch (this) {
    OBDProtocol.auto         => 'ATSP0',
    OBDProtocol.can11bit     => 'ATSP6',
    OBDProtocol.can29bit     => 'ATSP7',
    OBDProtocol.kwp2000Fast  => 'ATSP5',
    OBDProtocol.kwp2000Slow  => 'ATSP4',
    OBDProtocol.iso9141      => 'ATSP3',
  };

  String get displayName => switch (this) {
    OBDProtocol.auto         => 'Auto-detect',
    OBDProtocol.can11bit     => 'CAN 11-bit (ISO 15765-4)',
    OBDProtocol.can29bit     => 'CAN 29-bit (ISO 15765-4)',
    OBDProtocol.kwp2000Fast  => 'KWP2000 Fast Init (ISO 14230-4)',
    OBDProtocol.kwp2000Slow  => 'KWP2000 Slow Init (ISO 14230-4)',
    OBDProtocol.iso9141      => 'ISO 9141-2',
  };
}

/// Abstract interface for all ECU communication adapters.
///
/// Concrete implementations:
///   - [Elm327BluetoothAdapter]  — real Bluetooth Classic ELM327
///   - [MockAdapter]             — simulated responses for dev/testing
///
/// Planned future implementations:
///   - VgateVLinkerAdapter       — K-Line raw byte passthrough via AT passthrough
///   - OpenPort2Adapter          — J2534 USB interface (full write capability)
///   - KLineDirectAdapter        — custom hardware raw K-Line bus
abstract class AdapterInterface {
  /// Human-readable adapter name for UI display.
  String get adapterName;

  /// Machine identifier: 'elm327_bt', 'elm327_wifi', 'openport2', 'mock'
  String get adapterType;

  /// True if this adapter can pass raw K-Line bytes to the ECU.
  /// Required for KWP2000 low-level ECU read/write operations.
  bool get supportsKLineDirect;

  /// True if this adapter has write capability (can flash ECU).
  /// ELM327 is always false. OpenPort2 is true.
  bool get supportsWrite;

  Stream<AdapterConnectionStatus> get statusStream;
  AdapterConnectionStatus get connectionStatus;
  bool get isConnected;

  /// Connect to a device at the given address (MAC for BT, IP for WiFi, path for USB).
  Future<bool> connect(String deviceAddress);

  /// Disconnect and clean up resources.
  Future<void> disconnect();

  /// Send an AT-command or OBD-II hex PID string.
  /// ELM327 format: '010C' → sends '010C\r' → returns '410C1AF8\r\n>'
  /// Returns null on timeout or when not connected.
  Future<String?> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  });

  /// Send raw bytes and receive raw byte response.
  /// Only valid when [supportsKLineDirect] == true.
  /// Returns null for adapters that don't support raw mode.
  Future<Uint8List?> sendRawBytes(
    Uint8List bytes, {
    Duration timeout = const Duration(seconds: 5),
  });

  /// Configure the active OBD/ECU protocol on the adapter.
  Future<bool> setProtocol(OBDProtocol protocol);

  /// Set the KWP2000 target ECU address header.
  /// Example: '6810F1' for Honda Keihin ECU addressing.
  Future<bool> setHeader(String hexHeader);

  /// Release any resources held by this adapter.
  void dispose();
}
