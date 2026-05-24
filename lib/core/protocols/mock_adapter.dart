import 'dart:async';
import 'dart:typed_data';
import 'adapter_interface.dart';

/// Mock adapter that simulates ELM327 responses for development and automated tests.
/// Produces realistic cycling RPM values so the UI stays live without real hardware.
class MockAdapter implements AdapterInterface {
  final StreamController<AdapterConnectionStatus> _statusController =
      StreamController<AdapterConnectionStatus>.broadcast();
  AdapterConnectionStatus _status = AdapterConnectionStatus.disconnected;
  int _pollCount = 0;

  @override String get adapterName => 'Mock ELM327 (Dev)';
  @override String get adapterType => 'mock';
  @override bool get supportsKLineDirect => false;
  @override bool get supportsWrite => false;

  @override Stream<AdapterConnectionStatus> get statusStream => _statusController.stream;
  @override AdapterConnectionStatus get connectionStatus => _status;
  @override bool get isConnected => _status == AdapterConnectionStatus.connected;

  void _setStatus(AdapterConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  @override
  Future<bool> connect(String deviceAddress) async {
    _setStatus(AdapterConnectionStatus.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _pollCount = 0;
    _setStatus(AdapterConnectionStatus.connected);
    return true;
  }

  @override
  Future<void> disconnect() async {
    _setStatus(AdapterConnectionStatus.disconnected);
  }

  @override
  Future<String?> sendCommand(String command, {Duration timeout = const Duration(seconds: 3)}) async {
    if (!isConnected) return null;
    await Future<void>.delayed(const Duration(milliseconds: 55));
    return _simulateResponse(command.trim().toUpperCase());
  }

  @override
  Future<Uint8List?> sendRawBytes(Uint8List bytes, {Duration timeout = const Duration(seconds: 5)}) async {
    return null; // Mock doesn't support raw bytes
  }

  @override
  Future<bool> setProtocol(OBDProtocol protocol) async => true;

  @override
  Future<bool> setHeader(String hexHeader) async => true;

  @override
  void dispose() => _statusController.close();

  String _simulateResponse(String command) {
    _pollCount++;
    // Cycle RPM realistically: idle 1000 → builds to 6000 → back down
    final cyclePos = _pollCount % 60;
    final rpmRaw = cyclePos < 30
        ? 1000 + cyclePos * 165   // climbing
        : 1000 + (60 - cyclePos) * 165; // falling

    // IAT oscillates between 32–45°C (simulates warming)
    final iatRaw = 72 + (_pollCount % 15); // 72-40=32°C to 86-40=46°C

    switch (command) {
      case 'ATZ':   return 'ELM327 v2.1\r\n>';
      case 'ATE0':
      case 'ATL0':
      case 'ATH0':
      case 'ATSP0':
      case 'ATSP5':
      case 'ATSP6': return 'OK\r\n>';
      case '0100':  return '4100BE3EA813\r\n>';
      case '010C':  // RPM: ((A*256)+B)/4
        final enc = (rpmRaw * 4).round();
        final a = (enc >> 8) & 0xFF;
        final b = enc & 0xFF;
        return '410C${a.toRadixString(16).padLeft(2, '0').toUpperCase()}'
               '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}\r\n>';
      case '0111':  // TPS 25%
        return '4111${(25 * 255 ~/ 100).toRadixString(16).padLeft(2, '0').toUpperCase()}\r\n>';
      case '0105':  // Coolant 81°C (0x79=121, 121-40=81)
        return '410579\r\n>';
      case 'ATRV':  // Battery
        return '12.6V\r\n>';
      case '0114':  // O2 ~0.45V
        return '41145A\r\n>';
      case '010B':  // MAP 95 kPa
        return '410B5F\r\n>';
      case '010F':  // IAT
        return '410F${iatRaw.toRadixString(16).padLeft(2, '0').toUpperCase()}\r\n>';
      case '0104':  // Engine load ~35%: A=89=0x59 → 89/255×100=34.9%
        return '410459\r\n>';
      case '0106':  // Short-term fuel trim +3%: A=132=0x84 → (132-128)×100/128=3.1%
        return '410684\r\n>';
      case '0107':  // Long-term fuel trim +2%: A=131=0x83 → (131-128)×100/128=2.3%
        return '410783\r\n>';
      case '010A':  // Fuel pressure 300 kPa: A=100=0x64 → 100×3=300 kPa
        return '410A64\r\n>';
      case '0902':  // VIN — many motorcycle ECUs return NODATA
        return 'NODATA\r\n>';
      case '0904':  // Calibration ID
        return 'NODATA\r\n>';
      default:
        return 'NODATA\r\n>';
    }
  }
}
