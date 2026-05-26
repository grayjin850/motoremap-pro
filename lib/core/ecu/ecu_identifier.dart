import 'dart:typed_data';
import '../protocol/kwp_session.dart';

/// Result of reading ECU identification data via KWP2000 service 0x1A.
class EcuIdentificationResult {
  /// ECU part number (e.g. '37820-KYZ-901').
  final String partNumber;

  /// Software / calibration version string.
  final String softwareVersion;

  /// Hardware revision string.
  final String hardwareVersion;

  /// Calibration identifier (often same as or derived from softwareVersion).
  final String calibrationId;

  const EcuIdentificationResult({
    required this.partNumber,
    required this.softwareVersion,
    required this.hardwareVersion,
    required this.calibrationId,
  });

  @override
  String toString() =>
      'EcuIdentification{part=$partNumber, sw=$softwareVersion, '
      'hw=$hardwareVersion, cal=$calibrationId}';
}

/// Reads ECU identification data via KWP2000 service 0x1A (ReadEcuIdentification).
///
/// Service 0x1A uses sub-function record identifiers to request individual
/// identification records. Responses are ASCII-encoded strings.
///
/// Honda Click 125i: target address 0x10 (Keihin engine ECU)
/// Yamaha Aerox 155: target address 0x11 (Shindengen ECU)
class EcuIdentifier {
  EcuIdentifier._();

  // Service 0x1A record identifiers (sub-functions)
  static const int _service = 0x1A;
  static const int _idPartNumber = 0x87;      // ECU part number
  static const int _idHardwareVersion = 0x88; // Hardware version
  static const int _idSoftwareVersion = 0x89; // Software / calibration version

  /// Identify the connected ECU by reading its identification records.
  ///
  /// Reads part number, hardware version, and software version via
  /// three separate 0x1A requests. Missing records return empty strings.
  static Future<EcuIdentificationResult> identify(KwpSession session) async {
    final partNumber = await _readRecord(session, _idPartNumber);
    final hardwareVersion = await _readRecord(session, _idHardwareVersion);
    final softwareVersion = await _readRecord(session, _idSoftwareVersion);

    return EcuIdentificationResult(
      partNumber: partNumber,
      softwareVersion: softwareVersion,
      hardwareVersion: hardwareVersion,
      calibrationId: softwareVersion, // Keihin encodes calibration in SW version
    );
  }

  /// Read a single identification record.
  ///
  /// Returns the ASCII string content, or empty string if unavailable.
  static Future<String> _readRecord(KwpSession session, int recordId) async {
    try {
      final response = await session.sendService(
        _service,
        Uint8List.fromList([recordId]),
      );

      // Positive response: [recordId echo, data bytes...]
      if (response.isEmpty || response[0] != recordId) return '';

      // Data bytes are printable ASCII
      final dataBytes = response.sublist(1);
      return String.fromCharCodes(
        dataBytes.where((b) => b >= 0x20 && b <= 0x7E),
      ).trim();
    } catch (_) {
      return '';
    }
  }
}
