import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_remap_app/core/protocols/adapter_interface.dart';
import 'package:motorcycle_remap_app/core/protocol/kwp_session.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MockKwpAdapter — simulates an ECU responding to ISO14230-4 frames
// ─────────────────────────────────────────────────────────────────────────────

/// Simulates ECU KWP2000 responses for unit tests.
///
/// Register handlers per service ID via [onService]. Unregistered services
/// return a negative response with NRC 0x11 (service not supported).
class MockKwpAdapter implements AdapterInterface {
  final _statusCtrl = StreamController<AdapterConnectionStatus>.broadcast();

  final Map<int, Uint8List Function(Uint8List requestData)> _handlers = {};

  /// Configurable response delay (default 10ms simulates ECU processing time).
  Duration responseDelay;

  /// Set to true to simulate adapter returning null (timeout).
  bool forceTimeout;

  /// When set, the adapter returns null for the next N calls, then succeeds.
  int failFirstN;

  int _callCount = 0;

  MockKwpAdapter({
    this.responseDelay = const Duration(milliseconds: 10),
    this.forceTimeout = false,
    this.failFirstN = 0,
  });

  @override
  String get adapterName => 'MockKwpAdapter';
  @override
  String get adapterType => 'mock_kwp';
  @override
  bool get supportsKLineDirect => true;
  @override
  bool get supportsWrite => true;
  @override
  Stream<AdapterConnectionStatus> get statusStream => _statusCtrl.stream;
  @override
  AdapterConnectionStatus get connectionStatus => AdapterConnectionStatus.connected;
  @override
  bool get isConnected => true;
  @override
  Future<bool> connect(String deviceAddress) async => true;
  @override
  Future<void> disconnect() async {}
  @override
  Future<String?> sendCommand(String c, {Duration timeout = const Duration(seconds: 3)}) async => null;
  @override
  Future<bool> setProtocol(OBDProtocol p) async => true;
  @override
  Future<bool> setHeader(String h) async => true;
  @override
  void dispose() => _statusCtrl.close();

  void onService(int serviceId, Uint8List Function(Uint8List) handler) {
    _handlers[serviceId] = handler;
  }

  /// Register a handler that returns a raw negative response frame for [serviceId].
  void onServiceNrc(int serviceId, int nrc) {
    _handlers[serviceId] = (_) => _makeNegativeFrame(serviceId, nrc);
  }

  @override
  Future<Uint8List?> sendRawBytes(
    Uint8List bytes, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await Future<void>.delayed(responseDelay);
    _callCount++;

    if (forceTimeout) return null;
    if (_callCount <= failFirstN) return null;

    // Parse ISO14230-4 frame to extract service ID and request data
    final parsed = _parseFrame(bytes);
    if (parsed == null) return null;

    final serviceId = parsed.$1;
    final requestData = parsed.$2;

    final handler = _handlers[serviceId];
    if (handler == null) {
      // Default: NRC 0x11 (service not supported)
      return _wrapInFrame(_makeNegativePayload(serviceId, 0x11));
    }

    final responsePayload = handler(requestData);

    // If the handler already returned a full frame (starts with 0x80), return as-is
    if (responsePayload.isNotEmpty && (responsePayload[0] & 0xC0) == 0x80) {
      return responsePayload;
    }

    return _wrapInFrame(responsePayload);
  }

  // ── Internal frame helpers ──────────────────────────────────────────────

  /// Parse an ISO14230-4 addressed frame and return (serviceId, requestData).
  (int, Uint8List)? _parseFrame(Uint8List frame) {
    if (frame.length < 4) return null;
    final format = frame[0];
    if ((format & 0xC0) != 0x80) return null;

    final inlineLen = format & 0x3F;
    int payloadStart;

    if (inlineLen > 0) {
      payloadStart = 3;
    } else {
      if (frame.length < 5) return null;
      payloadStart = 4;
    }

    if (payloadStart >= frame.length - 1) return null;
    final serviceId = frame[payloadStart];
    final data = Uint8List.fromList(
      frame.sublist(payloadStart + 1, frame.length - 1), // strip checksum
    );
    return (serviceId, data);
  }

  /// Build a positive response frame around [payload].
  Uint8List _wrapInFrame(Uint8List payload) {
    final List<int> frame = [];
    frame.add(payload.length <= 63 ? 0x80 | payload.length : 0x80);
    frame.add(0xF1); // target = tester
    frame.add(0x10); // source = ECU
    if (payload.length > 63) frame.add(payload.length);
    frame.addAll(payload);
    final cs = frame.fold<int>(0, (s, b) => (s + b) & 0xFF);
    frame.add(cs);
    return Uint8List.fromList(frame);
  }

  Uint8List _makeNegativeFrame(int serviceId, int nrc) =>
      _wrapInFrame(_makeNegativePayload(serviceId, nrc));

  Uint8List _makeNegativePayload(int serviceId, int nrc) =>
      Uint8List.fromList([0x7F, serviceId, nrc]);

  /// Build a positive response payload: [responseServiceId, ...data]
  static Uint8List positivePayload(int serviceId, List<int> data) =>
      Uint8List.fromList([serviceId | 0x40, ...data]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Frame building ────────────────────────────────────────────────────────

  group('KwpSession.buildFrame', () {
    late KwpSession session;

    setUp(() {
      final adapter = MockKwpAdapter();
      session = KwpSession(adapter: adapter, targetAddress: 0x10);
    });

    tearDown(() => session.dispose());

    test('1. StartCommunication frame structure', () {
      // Service 0x81, no data → payload length = 1
      final frame = session.buildFrame(0x81, Uint8List(0));

      expect(frame[0], equals(0x80 | 1), reason: 'format byte: 0x81');
      expect(frame[1], equals(0x10), reason: 'target = ECU');
      expect(frame[2], equals(0xF1), reason: 'source = tester');
      expect(frame[3], equals(0x81), reason: 'service ID');

      // Checksum = sum of all bytes except last, mod 256
      final expectedCs = frame.sublist(0, frame.length - 1)
          .fold<int>(0, (s, b) => (s + b) & 0xFF);
      expect(frame.last, equals(expectedCs), reason: 'checksum');
    });

    test('2. Frame with data bytes includes all bytes before checksum', () {
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);
      final frame = session.buildFrame(0x23, data);

      // payloadLen = 1 (serviceId) + 3 (data) = 4
      expect(frame[0], equals(0x80 | 4), reason: 'format byte');
      expect(frame[3], equals(0x23), reason: 'service ID');
      expect(frame[4], equals(0x01));
      expect(frame[5], equals(0x02));
      expect(frame[6], equals(0x03));

      final expectedCs = frame.sublist(0, frame.length - 1)
          .fold<int>(0, (s, b) => (s + b) & 0xFF);
      expect(frame.last, equals(expectedCs));
    });

    test('3. Frame total length = 4 + data.length + 1 (header+cs)', () {
      final data = Uint8List.fromList([0xAA, 0xBB]);
      final frame = session.buildFrame(0x27, data);
      // 1 (format) + 1 (target) + 1 (source) + 1 (serviceId) + 2 (data) + 1 (cs) = 7
      expect(frame.length, equals(7));
    });
  });

  // ── Payload extraction ────────────────────────────────────────────────────

  group('KwpSession.extractPayload', () {
    late KwpSession session;

    setUp(() {
      session = KwpSession(
        adapter: MockKwpAdapter(),
        targetAddress: 0x10,
      );
    });

    tearDown(() => session.dispose());

    test('4. Extract payload from inline-length frame', () {
      // Frame: [0x84, 0xF1, 0x10, 0xC1, 0x8F, 0x6B, cs]
      // format 0x84 → inline len = 4 → payload starts at index 3, length 4
      final payload = [0xC1, 0x8F, 0x6B, 0x00];
      final frame = [0x80 | payload.length, 0xF1, 0x10, ...payload];
      final cs = frame.fold<int>(0, (s, b) => (s + b) & 0xFF);
      frame.add(cs);

      final extracted = session.extractPayload(Uint8List.fromList(frame));
      expect(extracted, equals(Uint8List.fromList(payload)));
    });

    test('5. Extract payload from separate-length frame (payload > 63)', () {
      // format 0x80 → length in byte 3
      final payload = List.generate(64, (i) => i); // 64 bytes
      final frame = [0x80, 0xF1, 0x10, payload.length, ...payload];
      final cs = frame.fold<int>(0, (s, b) => (s + b) & 0xFF);
      frame.add(cs);

      final extracted = session.extractPayload(Uint8List.fromList(frame));
      expect(extracted, equals(Uint8List.fromList(payload)));
    });

    test('6. Empty / too-short frame returns empty', () {
      expect(session.extractPayload(Uint8List(0)), isEmpty);
      expect(session.extractPayload(Uint8List.fromList([0x80])), isEmpty);
    });
  });

  // ── Session start ─────────────────────────────────────────────────────────

  group('KwpSession.startSession', () {
    test('7. Successful StartCommunication → session becomes active', () async {
      final adapter = MockKwpAdapter();
      // Register 0x81 handler: return [0xC1, keyByte1, keyByte2]
      adapter.onService(
        0x81,
        (_) => MockKwpAdapter.positivePayload(0x81, [0x8F, 0x6B]),
      );

      final session = KwpSession(adapter: adapter, targetAddress: 0x10);
      await session.startSession();

      expect(session.isActive, isTrue);
      session.dispose();
    });

    test('8. Wrong response byte → throws KwpTimeoutException', () async {
      final adapter = MockKwpAdapter();
      // Return a wrong response ID (not 0xC1)
      adapter.onService(
        0x81,
        (_) => MockKwpAdapter.positivePayload(0x99, []),
      );

      final session = KwpSession(adapter: adapter, targetAddress: 0x10);
      await expectLater(
        () => session.startSession(),
        throwsA(isA<KwpTimeoutException>()),
      );
      session.dispose();
    });

    test('9. Adapter returns null → throws KwpTimeoutException after retries', () async {
      final adapter = MockKwpAdapter(forceTimeout: true);
      final session = KwpSession(adapter: adapter, targetAddress: 0x10);

      await expectLater(
        () => session.startSession(),
        throwsA(isA<KwpTimeoutException>()),
      );
      session.dispose();
    });
  });

  // ── Service call ──────────────────────────────────────────────────────────

  group('KwpSession.sendService', () {
    late MockKwpAdapter adapter;
    late KwpSession session;

    setUp(() async {
      adapter = MockKwpAdapter();
      adapter.onService(
        0x81,
        (_) => MockKwpAdapter.positivePayload(0x81, [0x8F, 0x6B]),
      );
      session = KwpSession(adapter: adapter, targetAddress: 0x10);
      await session.startSession();
    });

    tearDown(() => session.dispose());

    test('10. sendService returns response data (without response service ID)', () async {
      // Register 0x1A (ReadEcuIdentification)
      adapter.onService(
        0x1A,
        (_) => MockKwpAdapter.positivePayload(0x1A, [0x87, 0x33, 0x37, 0x38, 0x32, 0x30]),
      );

      final response = await session.sendService(0x1A, Uint8List.fromList([0x87]));
      // Should return [0x87, 0x33, 0x37, 0x38, 0x32, 0x30] (echo + ASCII bytes)
      expect(response[0], equals(0x87));
    });

    test('11. NRC 0x11 → throws KwpNegativeResponseException', () async {
      adapter.onServiceNrc(0x2A, 0x11);

      await expectLater(
        () => session.sendService(0x2A, Uint8List(0)),
        throwsA(isA<KwpNegativeResponseException>()),
      );
    });

    test('12. NRC code in exception matches response', () async {
      adapter.onServiceNrc(0x27, 0x35); // invalid key

      try {
        await session.sendService(0x27, Uint8List.fromList([0x02, 0xFF, 0xFF]));
        fail('Expected KwpNegativeResponseException');
      } on KwpNegativeResponseException catch (e) {
        expect(e.nrcCode, equals(0x35));
        expect(e.nrc, equals(KwpNrc.invalidKey));
      }
    });

    test('13. sendService before startSession → throws KwpTimeoutException', () async {
      final freshAdapter = MockKwpAdapter();
      final freshSession = KwpSession(adapter: freshAdapter, targetAddress: 0x10);

      await expectLater(
        () => freshSession.sendService(0x1A, Uint8List(0)),
        throwsA(isA<KwpTimeoutException>()),
      );
      freshSession.dispose();
    });

    test('14. ReadMemoryByAddress (0x23) returns correct simulated chunk', () async {
      // Simulate ECU returning 4 bytes from address 0x4000
      adapter.onService(
        0x23,
        (data) {
          // data: [addrHigh, addrMid, addrLow, length]
          expect(data.length, equals(4));
          final len = data[3];
          return MockKwpAdapter.positivePayload(
            0x23,
            List.generate(len, (i) => (0xDE + i) & 0xFF),
          );
        },
      );

      final result = await session.sendService(
        0x23,
        Uint8List.fromList([0x00, 0x40, 0x00, 0x04]),
      );
      expect(result.length, equals(4));
      expect(result[0], equals(0xDE));
      expect(result[1], equals(0xDF));
    });
  });

  // ── NRC enum ─────────────────────────────────────────────────────────────

  group('KwpNrc enum', () {
    test('15. fromByte returns correct enum for known codes', () {
      expect(KwpNrc.fromByte(0x10), equals(KwpNrc.generalReject));
      expect(KwpNrc.fromByte(0x35), equals(KwpNrc.invalidKey));
      expect(KwpNrc.fromByte(0x78), equals(KwpNrc.responsePending));
    });

    test('16. fromByte returns null for unknown code', () {
      expect(KwpNrc.fromByte(0xFF), isNull);
    });
  });
}
