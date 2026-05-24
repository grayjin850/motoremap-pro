import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'adapter_interface.dart';

/// Real Bluetooth Classic ELM327 adapter implementation.
///
/// Uses flutter_bluetooth_serial (RFCOMM/SPP) to communicate with
/// ELM327-compatible OBD adapters (Vgate vLinker MC+, OBDLink MX+, etc.).
///
/// Android 12+ requirements: BLUETOOTH_CONNECT + BLUETOOTH_SCAN in manifest.
/// See AndroidManifest.xml for the full permission set.
class Elm327BluetoothAdapter implements AdapterInterface {
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;

  final StreamController<AdapterConnectionStatus> _statusController =
      StreamController<AdapterConnectionStatus>.broadcast();
  AdapterConnectionStatus _status = AdapterConnectionStatus.disconnected;

  final StringBuffer _responseBuffer = StringBuffer();
  Completer<String>? _pendingResponse;

  @override String get adapterName => 'ELM327 Bluetooth';
  @override String get adapterType => 'elm327_bt';
  @override bool get supportsKLineDirect => false;
  @override bool get supportsWrite => false;

  @override Stream<AdapterConnectionStatus> get statusStream => _statusController.stream;
  @override AdapterConnectionStatus get connectionStatus => _status;
  @override bool get isConnected => _status == AdapterConnectionStatus.connected;

  void _setStatus(AdapterConnectionStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  @override
  Future<bool> connect(String deviceAddress) async {
    _setStatus(AdapterConnectionStatus.connecting);
    try {
      _connection = await BluetoothConnection.toAddress(deviceAddress);
      _listenToInput();
      _setStatus(AdapterConnectionStatus.connected);
      return true;
    } catch (e) {
      _setStatus(AdapterConnectionStatus.error);
      return false;
    }
  }

  void _listenToInput() {
    _inputSubscription = _connection!.input!.listen(
      (Uint8List data) {
        final chunk = utf8.decode(data, allowMalformed: true);
        _responseBuffer.write(chunk);
        // ELM327 ends every response with '>' prompt character
        if (_responseBuffer.toString().contains('>')) {
          final response = _responseBuffer.toString();
          _responseBuffer.clear();
          _pendingResponse?.complete(response);
          _pendingResponse = null;
        }
      },
      onDone: () {
        _setStatus(AdapterConnectionStatus.disconnected);
        _pendingResponse?.completeError('Connection closed');
        _pendingResponse = null;
      },
      onError: (dynamic e) {
        _setStatus(AdapterConnectionStatus.error);
        _pendingResponse?.completeError(e);
        _pendingResponse = null;
      },
      cancelOnError: true,
    );
  }

  @override
  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
    _pendingResponse?.completeError('Disconnected by user');
    _pendingResponse = null;
    _setStatus(AdapterConnectionStatus.disconnected);
  }

  @override
  Future<String?> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!isConnected || _connection == null) return null;
    // Cancel any in-flight pending response before sending a new command
    _pendingResponse?.completeError('Superseded');
    _responseBuffer.clear();

    try {
      _pendingResponse = Completer<String>();
      final bytes = Uint8List.fromList(utf8.encode('$command\r'));
      _connection!.output.add(bytes);
      await _connection!.output.allSent;
      return await _pendingResponse!.future.timeout(timeout);
    } on TimeoutException {
      _pendingResponse = null;
      return null;
    } catch (_) {
      _pendingResponse = null;
      return null;
    }
  }

  @override
  Future<Uint8List?> sendRawBytes(
    Uint8List bytes, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Standard ELM327 does not expose raw K-Line bytes.
    // Use VgateVLinkerAdapter with AT passthrough commands for this.
    return null;
  }

  @override
  Future<bool> setProtocol(OBDProtocol protocol) async {
    final resp = await sendCommand(protocol.atCommand);
    return resp?.trim().toUpperCase().contains('OK') == true;
  }

  @override
  Future<bool> setHeader(String hexHeader) async {
    final resp = await sendCommand('ATSH $hexHeader');
    return resp?.trim().toUpperCase().contains('OK') == true;
  }

  @override
  void dispose() {
    disconnect();
    _statusController.close();
  }

  // ---------------------------------------------------------------------------
  // Static helpers for device scanning
  // ---------------------------------------------------------------------------

  /// Returns a list of Bluetooth Classic devices already paired with the phone.
  /// These are the candidates for OBD adapter connection.
  static Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  /// Heuristic: is this BT device likely an OBD/ELM327 adapter?
  static bool isLikelyOBDAdapter(BluetoothDevice device) {
    final name = (device.name ?? '').toLowerCase();
    return name.contains('obd') ||
        name.contains('elm') ||
        name.contains('vlink') ||
        name.contains('scan') ||
        name.contains('diag') ||
        name.contains('obdii');
  }
}
