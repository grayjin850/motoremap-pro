import 'dart:async';
import 'dart:typed_data';
import '../protocols/adapter_interface.dart';

/// KWP2000 negative response codes (ISO 14229-1 / ISO 14230-4).
enum KwpNrc {
  generalReject(0x10, 'General reject'),
  serviceNotSupported(0x11, 'Service not supported'),
  subFunctionNotSupported(0x12, 'Sub-function not supported'),
  incorrectMessageLength(0x13, 'Incorrect message length or format'),
  conditionsNotCorrect(0x22, 'Conditions not correct'),
  requestSequenceError(0x24, 'Request sequence error'),
  requestOutOfRange(0x31, 'Request out of range'),
  securityAccessDenied(0x33, 'Security access denied'),
  invalidKey(0x35, 'Invalid key'),
  exceededNumberOfAttempts(0x36, 'Exceeded number of attempts'),
  requiredTimeDelayNotExpired(0x37, 'Required time delay not expired'),
  uploadDownloadNotAccepted(0x40, 'Upload/download not accepted'),
  generalProgrammingFailure(0x42, 'General programming failure'),
  wrongBlockSequenceCounter(0x43, 'Wrong block sequence counter'),
  responsePending(0x78, 'Request received, response pending');

  final int code;
  final String description;
  const KwpNrc(this.code, this.description);

  static KwpNrc? fromByte(int byte) {
    for (final nrc in values) {
      if (nrc.code == byte) return nrc;
    }
    return null;
  }
}

class KwpNegativeResponseException implements Exception {
  final int requestedServiceId;
  final KwpNrc? nrc;
  final int nrcCode;

  KwpNegativeResponseException({
    required this.requestedServiceId,
    required this.nrcCode,
  }) : nrc = KwpNrc.fromByte(nrcCode);

  @override
  String toString() {
    final desc = nrc?.description ?? '0x${nrcCode.toRadixString(16).padLeft(2, '0')}';
    return 'KWP NRC for service '
        '0x${requestedServiceId.toRadixString(16).padLeft(2, '0')}: $desc';
  }
}

class KwpTimeoutException implements Exception {
  final String message;
  const KwpTimeoutException(this.message);
  @override
  String toString() => 'KWP timeout: $message';
}

/// ISO 14230-4 KWP2000 session over a raw K-Line adapter.
///
/// Handles:
/// - ISO 14230-4 addressed frame building (0x80 family)
/// - Fast-init session start via service 0x81
/// - Service request/response with NRC handling
/// - Automatic keep-alive (TesterPresent 0x3E every 2 seconds)
/// - Retry logic (up to 3 attempts per request)
class KwpSession {
  final AdapterInterface adapter;

  /// ECU target address. Honda Keihin = 0x10, Yamaha Shindengen = 0x11.
  final int targetAddress;

  /// Tester (our device) source address. Always 0xF1 per ISO 14230-4.
  final int sourceAddress;

  static const int _testerAddress = 0xF1;
  static const int _maxRetries = 3;
  static const Duration _responseTimeout = Duration(seconds: 3);
  static const Duration _keepAliveInterval = Duration(seconds: 2);

  Timer? _keepAliveTimer;
  bool _active = false;
  bool _keepAlivePaused = false;

  KwpSession({
    required this.adapter,
    required this.targetAddress,
    this.sourceAddress = _testerAddress,
  });

  bool get isActive => _active;

  /// Start a KWP2000 session via fast-init StartCommunicationRequest (0x81).
  ///
  /// The adapter is expected to handle the physical K-Line fast-init timing
  /// (25ms break, 25ms idle) before sending this frame.
  Future<void> startSession() async {
    Exception? lastError;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final frame = buildFrame(0x81, Uint8List(0));
        final raw = await adapter.sendRawBytes(
          frame,
          timeout: const Duration(seconds: 5),
        );

        if (raw == null || raw.isEmpty) {
          lastError = const KwpTimeoutException(
            'No response to StartCommunicationRequest',
          );
          if (attempt < _maxRetries - 1) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            continue;
          }
          throw lastError;
        }

        final payload = extractPayload(raw);
        // Positive response to 0x81 is 0xC1 (0x81 | 0x40)
        if (payload.isEmpty || payload[0] != 0xC1) {
          lastError = KwpTimeoutException(
            'Unexpected StartCommunication response: '
            '0x${payload.isNotEmpty ? payload[0].toRadixString(16).padLeft(2, "0") : "empty"}',
          );
          if (attempt < _maxRetries - 1) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            continue;
          }
          throw lastError;
        }

        _active = true;
        _startKeepAlive();
        return;
      } on KwpNegativeResponseException {
        rethrow;
      } catch (e) {
        lastError = e as Exception;
        if (attempt < _maxRetries - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }
    throw lastError ?? const KwpTimeoutException('startSession failed after retries');
  }

  /// Send a KWP2000 service request and return the response payload.
  ///
  /// The returned [Uint8List] contains the response data bytes (without the
  /// positive response service ID byte 0x40|serviceId).
  ///
  /// Throws [KwpNegativeResponseException] on ECU NRC responses.
  /// Throws [KwpTimeoutException] on no response after retries.
  Future<Uint8List> sendService(int serviceId, Uint8List data) async {
    if (!_active) {
      throw const KwpTimeoutException('No active KWP2000 session');
    }

    final frame = buildFrame(serviceId, data);
    Exception? lastError;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final raw = await adapter.sendRawBytes(frame, timeout: _responseTimeout);

        if (raw == null || raw.isEmpty) {
          lastError = KwpTimeoutException(
            'No response to service '
            '0x${serviceId.toRadixString(16).padLeft(2, "0")}',
          );
          if (attempt < _maxRetries - 1) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            continue;
          }
          throw lastError;
        }

        final payload = extractPayload(raw);
        if (payload.isEmpty) {
          lastError = const KwpTimeoutException('Empty payload received');
          if (attempt < _maxRetries - 1) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            continue;
          }
          throw lastError;
        }

        // Negative response: [0x7F, echoedServiceId, NRC]
        if (payload[0] == 0x7F) {
          if (payload.length >= 3) {
            final nrcByte = payload[2];
            // ResponsePending (0x78): ECU still processing — retry
            if (nrcByte == KwpNrc.responsePending.code) {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              continue; // don't count against retry limit
            }
            throw KwpNegativeResponseException(
              requestedServiceId: payload.length > 1 ? payload[1] : serviceId,
              nrcCode: nrcByte,
            );
          }
          throw KwpNegativeResponseException(
            requestedServiceId: serviceId,
            nrcCode: 0x10,
          );
        }

        // Positive response: first byte = serviceId | 0x40
        final expectedId = serviceId | 0x40;
        if (payload[0] != expectedId) {
          lastError = KwpTimeoutException(
            'Wrong response ID: expected '
            '0x${expectedId.toRadixString(16)}, '
            'got 0x${payload[0].toRadixString(16)}',
          );
          if (attempt < _maxRetries - 1) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            continue;
          }
          throw lastError;
        }

        return Uint8List.fromList(payload.sublist(1));
      } on KwpNegativeResponseException {
        rethrow;
      } catch (e) {
        lastError = e as Exception;
        if (attempt < _maxRetries - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }
    throw lastError ??
        KwpTimeoutException(
          'Service 0x${serviceId.toRadixString(16)} failed after $_maxRetries attempts',
        );
  }

  /// Send StopCommunicationRequest (0x82) and clean up.
  Future<void> stopSession() async {
    _stopKeepAlive();
    if (_active) {
      try {
        await sendService(0x82, Uint8List(0));
      } catch (_) {}
      _active = false;
    }
  }

  /// Suspend keep-alive during bulk ROM reads to avoid frame collisions.
  void pauseKeepAlive() => _keepAlivePaused = true;

  /// Resume keep-alive after bulk read completes.
  void resumeKeepAlive() => _keepAlivePaused = false;

  /// Build an ISO 14230-4 addressed frame.
  ///
  /// Format: [0x80|len, targetAddr, sourceAddr, serviceId, ...data, checksum]
  /// If payload > 63 bytes: [0x80, targetAddr, sourceAddr, lenByte, serviceId, ...data, checksum]
  Uint8List buildFrame(int serviceId, Uint8List data) {
    final payloadLen = 1 + data.length; // serviceId + data bytes
    final List<int> frame = [];

    if (payloadLen <= 63) {
      frame.add(0x80 | payloadLen);
    } else {
      frame.add(0x80); // length in next dedicated byte
    }
    frame.add(targetAddress);
    frame.add(sourceAddress);
    if (payloadLen > 63) frame.add(payloadLen);

    frame.add(serviceId);
    frame.addAll(data);

    final checksum = frame.fold<int>(0, (sum, b) => (sum + b) & 0xFF);
    frame.add(checksum);

    return Uint8List.fromList(frame);
  }

  /// Extract the payload bytes from a received ISO 14230-4 frame.
  ///
  /// Handles both inline-length (0x80|len) and separate-length (0x80 + lenByte) formats.
  Uint8List extractPayload(Uint8List frame) {
    if (frame.length < 2) return Uint8List(0);

    final format = frame[0];

    if ((format & 0xC0) == 0x80) {
      final inlineLen = format & 0x3F;

      if (inlineLen == 0) {
        // Length in dedicated byte at position 3, payload starts at 4
        if (frame.length < 5) return Uint8List(0);
        final len = frame[3];
        final start = 4;
        final end = start + len;
        if (end > frame.length) return Uint8List(0);
        return Uint8List.fromList(frame.sublist(start, end));
      } else {
        // Length encoded in format byte, payload starts at 3
        final start = 3;
        final end = start + inlineLen;
        if (end > frame.length) return Uint8List(0);
        return Uint8List.fromList(frame.sublist(start, end));
      }
    }

    // Non-addressed frame: everything except last checksum byte
    if (frame.length > 1) {
      return Uint8List.fromList(frame.sublist(0, frame.length - 1));
    }
    return Uint8List(0);
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) async {
      if (!_active || _keepAlivePaused) return;
      try {
        await sendService(0x3E, Uint8List(0));
      } catch (_) {
        _active = false;
        _keepAliveTimer?.cancel();
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void dispose() {
    _stopKeepAlive();
    _active = false;
  }
}
