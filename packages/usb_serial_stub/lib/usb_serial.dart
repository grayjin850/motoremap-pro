import 'dart:async';
import 'dart:typed_data';

// Stub implementation — no real USB hardware on Windows desktop.
// All methods return empty/false/null so the UI opens without crashing.

class UsbSerial {
  static Future<List<UsbDevice>> listDevices() async => [];
}

class UsbDevice {
  final String? manufacturerName;
  final String? productName;
  final int vid;
  final int pid;

  const UsbDevice({
    this.manufacturerName,
    this.productName,
    this.vid = 0,
    this.pid = 0,
  });

  Future<UsbPort?> create() async => null;
}

class UsbPort {
  static const int DATABITS_8 = 8;
  static const int STOPBITS_1 = 1;
  static const int PARITY_NONE = 0;

  Stream<Uint8List>? get inputStream => null;

  Future<bool> open() async => false;
  Future<void> close() async {}
  Future<void> write(Uint8List data) async {}
  Future<void> setDTR(bool value) async {}
  Future<void> setRTS(bool value) async {}
  Future<void> setPortParameters(
    int baudRate,
    int dataBits,
    int stopBits,
    int parity,
  ) async {}
}
