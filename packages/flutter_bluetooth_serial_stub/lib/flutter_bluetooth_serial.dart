import 'dart:async';
import 'dart:typed_data';

// Stub implementation — no Bluetooth Classic on Windows desktop.
// All methods return empty/false/null so the UI opens without crashing.

class BluetoothDevice {
  final String? name;
  final String address;

  const BluetoothDevice({this.name, required this.address});
}

class _StubSink {
  void add(Uint8List data) {}
  Future<void> get allSent async {}
}

class BluetoothConnection {
  Stream<Uint8List>? get input => null;
  _StubSink get output => _StubSink();

  static Future<BluetoothConnection> toAddress(String address) async {
    throw UnsupportedError('Bluetooth not available on desktop');
  }

  Future<void> close() async {}
  bool get isConnected => false;
}

class FlutterBluetoothSerial {
  static final FlutterBluetoothSerial instance = FlutterBluetoothSerial._();
  FlutterBluetoothSerial._();

  Future<List<BluetoothDevice>> getBondedDevices() async => [];
}
