import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'adapter_interface.dart';

/// K-Line USB adapter for OpenPort 2.0 and compatible USB-to-K-Line interfaces.
///
/// Supports any adapter using FTDI FT232R, Silicon Labs CP2102, WCH CH340,
/// or Prolific PL2303 USB-to-serial chips — the four chips found in OpenPort 2.0
/// clones and K-Line USB adapters common in the Philippine tuning market.
///
/// K-Line protocol: ISO 14230-4 / KWP2000 fast-init
/// Baud: 10400, 8N1, no flow control
/// Half-duplex: TX bytes echo back — stripped automatically.
class KLineUsbAdapter implements AdapterInterface {
  static const int _kLineBaud = 10400;

  final _statusController =
      StreamController<AdapterConnectionStatus>.broadcast();
  AdapterConnectionStatus _status = AdapterConnectionStatus.disconnected;

  UsbPort? _port;
  StreamSubscription<Uint8List>? _rxSub;
  final _rxBuffer = <int>[];
  int _txEchoRemaining = 0;
  Completer<Uint8List?>? _pendingResponse;

  // ── AdapterInterface identity ─────────────────────────────────────────────

  @override
  String get adapterName => 'K-Line USB (OpenPort 2.0 / FTDI / CP2102 / CH340)';

  @override
  String get adapterType => 'kline_usb';

  @override
  bool get supportsKLineDirect => true;

  @override
  bool get supportsWrite => true;

  @override
  Stream<AdapterConnectionStatus> get statusStream => _statusController.stream;

  @override
  AdapterConnectionStatus get connectionStatus => _status;

  @override
  bool get isConnected => _status == AdapterConnectionStatus.connected;

  // ── Connection ────────────────────────────────────────────────────────────

  /// List all connected USB serial devices that match known K-Line adapter chips.
  static Future<List<UsbDevice>> listDevices() => UsbSerial.listDevices();

  /// Connect to a USB K-Line adapter.
  ///
  /// [deviceAddress] is ignored — the first enumerated USB serial device is
  /// used. If multiple devices are connected, call [listDevices] and use
  /// [connectToDevice] directly.
  @override
  Future<bool> connect(String deviceAddress) async {
    _setStatus(AdapterConnectionStatus.connecting);
    final devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      _setStatus(AdapterConnectionStatus.error);
      return false;
    }
    return connectToDevice(devices.first);
  }

  /// Connect to a specific [UsbDevice].
  Future<bool> connectToDevice(UsbDevice device) async {
    _setStatus(AdapterConnectionStatus.connecting);
    try {
      _port = await device.create();
      if (_port == null) {
        _setStatus(AdapterConnectionStatus.error);
        return false;
      }

      final opened = await _port!.open();
      if (!opened) {
        _setStatus(AdapterConnectionStatus.error);
        return false;
      }

      // K-Line: 10400 baud, 8 data bits, 1 stop bit, no parity, no flow control
      await _port!.setDTR(true);
      await _port!.setRTS(true);
      await _port!.setPortParameters(
        _kLineBaud,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _rxBuffer.clear();
      _rxSub = _port!.inputStream?.listen(
        _onBytesReceived,
        onError: _onRxError,
        cancelOnError: false,
      );

      _setStatus(AdapterConnectionStatus.connected);
      return true;
    } catch (e) {
      _setStatus(AdapterConnectionStatus.error);
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _rxSub?.cancel();
    _rxSub = null;
    await _port?.close();
    _port = null;
    _rxBuffer.clear();
    _pendingResponse?.complete(null);
    _pendingResponse = null;
    _setStatus(AdapterConnectionStatus.disconnected);
  }

  // ── Communication ─────────────────────────────────────────────────────────

  /// Not supported — K-Line adapter does not speak ELM327 AT commands.
  @override
  Future<String?> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async =>
      null;

  /// Send raw ISO 14230-4 bytes over K-Line and receive the ECU's response.
  ///
  /// K-Line is half-duplex: after writing, the bus echoes back the same bytes.
  /// The echo is stripped automatically via [_txEchoRemaining].
  @override
  Future<Uint8List?> sendRawBytes(
    Uint8List bytes, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!isConnected || _port == null) return null;

    _rxBuffer.clear();
    _txEchoRemaining = bytes.length;

    final completer = Completer<Uint8List?>();
    _pendingResponse = completer;

    try {
      await _port!.write(bytes);
    } catch (e) {
      _pendingResponse = null;
      return null;
    }

    try {
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } finally {
      if (_pendingResponse == completer) _pendingResponse = null;
    }
  }

  // ── RX byte handling ──────────────────────────────────────────────────────

  void _onBytesReceived(Uint8List incoming) {
    for (final byte in incoming) {
      if (_txEchoRemaining > 0) {
        // Strip echo of our own transmitted bytes
        _txEchoRemaining--;
        continue;
      }
      _rxBuffer.add(byte);
    }

    if (_rxBuffer.isNotEmpty && _pendingResponse != null) {
      final frame = _tryExtractCompleteFrame();
      if (frame != null) {
        _pendingResponse!.complete(frame);
        _pendingResponse = null;
      }
    }
  }

  void _onRxError(Object error) {
    _pendingResponse?.complete(null);
    _pendingResponse = null;
  }

  /// Extract a complete ISO 14230-4 frame from [_rxBuffer] if available.
  /// Returns the frame bytes or null if more bytes are needed.
  Uint8List? _tryExtractCompleteFrame() {
    if (_rxBuffer.isEmpty) return null;

    final format = _rxBuffer[0];
    int expectedLen;

    if ((format & 0xC0) == 0x80) {
      final inlineLen = format & 0x3F;
      if (inlineLen > 0) {
        // Format byte encodes payload length
        // Total = 1 (format) + 1 (target) + 1 (source) + inlineLen + 1 (cs)
        expectedLen = 4 + inlineLen;
      } else {
        // Separate length byte at index 3
        if (_rxBuffer.length < 4) return null;
        final lenByte = _rxBuffer[3];
        // Total = 1 + 1 + 1 + 1 (lenByte field) + lenByte + 1 (cs)
        expectedLen = 5 + lenByte;
      }
    } else {
      // Unknown format — accumulate until we get a timeout
      return null;
    }

    if (_rxBuffer.length < expectedLen) return null;

    final frameBytes = _rxBuffer.sublist(0, expectedLen);
    final computed = frameBytes
        .sublist(0, expectedLen - 1)
        .fold<int>(0, (sum, b) => (sum + b) & 0xFF);

    if (computed != frameBytes[expectedLen - 1]) {
      // Checksum mismatch — discard first byte and retry on next call
      _rxBuffer.removeAt(0);
      return null;
    }

    _rxBuffer.removeRange(0, expectedLen);
    return Uint8List.fromList(frameBytes);
  }

  // ── Protocol stubs (not needed for K-Line) ────────────────────────────────

  @override
  Future<bool> setProtocol(OBDProtocol protocol) async => true;

  @override
  Future<bool> setHeader(String hexHeader) async => true;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void _setStatus(AdapterConnectionStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  @override
  void dispose() {
    _rxSub?.cancel();
    _port?.close();
    _pendingResponse?.complete(null);
    _statusController.close();
  }
}
