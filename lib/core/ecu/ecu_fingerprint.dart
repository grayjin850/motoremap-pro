import 'dart:typed_data';
import 'ecu_verification_manager.dart';

// ── ECU fingerprint ───────────────────────────────────────────────────────────

/// Unique identifier for a specific physical ECU unit.
///
/// Combines service 0x1A identification records (part number, hardware version,
/// software version, calibration ID) with the first-boot ROM hash to create
/// an identifier that distinguishes individual ECU units of the same model.
///
/// Example: two Honda Click 125i ECUs with the same part number but different
/// software versions will have different fingerprints.
///
/// Used by [EcuVerificationManager] to store separate verification records
/// per physical unit — preventing a tuner from accidentally applying a
/// different ECU's ROM offsets to a new unit.
class EcuFingerprint {
  /// The ECU model ID from [EcuDefinition.id] (e.g. 'honda_click_125i').
  final String ecuId;

  /// Part number string from service 0x1A record 0x87 (ASCII decoded).
  final String? partNumber;

  /// Hardware version from service 0x1A record 0x88 (ASCII decoded).
  final String? hardwareVersion;

  /// Software version from service 0x1A record 0x89 (ASCII decoded).
  final String? softwareVersion;

  /// Calibration ID (sometimes called 'tune ID') from record 0x97.
  final String? calibrationId;

  /// Simple hash of the first 256 bytes of the ROM — stable across power cycles,
  /// distinguishes ROM variants without requiring a full dump.
  final String? romPreambleHash;

  /// When this fingerprint was first recorded.
  final DateTime recordedAt;

  const EcuFingerprint({
    required this.ecuId,
    this.partNumber,
    this.hardwareVersion,
    this.softwareVersion,
    this.calibrationId,
    this.romPreambleHash,
    required this.recordedAt,
  });

  /// A short identifier string combining part number + SW version.
  /// Falls back to [ecuId] if identification records are unavailable.
  String get shortId {
    final parts = <String>[];
    if (partNumber != null) parts.add(partNumber!.trim());
    if (softwareVersion != null) parts.add('SW:${softwareVersion!.trim()}');
    if (parts.isEmpty) return ecuId;
    return parts.join(' | ');
  }

  /// Unique fingerprint hash — stable per physical unit.
  ///
  /// Computed from: ecuId + partNumber + hwVersion + swVersion + calId.
  /// Does NOT include romPreambleHash so the fingerprint survives reflashing.
  String get fingerprintHash {
    final key = [ecuId, partNumber ?? '', hardwareVersion ?? '',
      softwareVersion ?? '', calibrationId ?? ''].join('|');
    return _hash(key);
  }

  // ── Factory ───────────────────────────────────────────────────────────────

  /// Build a fingerprint from raw 0x1A identification bytes and an optional
  /// ROM preamble (first 256 bytes of a ROM dump).
  factory EcuFingerprint.fromIdentification({
    required String ecuId,
    List<int>? record87PartNumber,
    List<int>? record88HardwareVersion,
    List<int>? record89SoftwareVersion,
    List<int>? record97CalibrationId,
    Uint8List? romPreamble,
  }) {
    return EcuFingerprint(
      ecuId: ecuId,
      partNumber: record87PartNumber != null
          ? _decodeAscii(record87PartNumber)
          : null,
      hardwareVersion: record88HardwareVersion != null
          ? _decodeAscii(record88HardwareVersion)
          : null,
      softwareVersion: record89SoftwareVersion != null
          ? _decodeAscii(record89SoftwareVersion)
          : null,
      calibrationId: record97CalibrationId != null
          ? _decodeAscii(record97CalibrationId)
          : null,
      romPreambleHash: romPreamble != null ? _hashBytes(romPreamble) : null,
      recordedAt: DateTime.now(),
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'ecuId': ecuId,
        'partNumber': partNumber,
        'hardwareVersion': hardwareVersion,
        'softwareVersion': softwareVersion,
        'calibrationId': calibrationId,
        'romPreambleHash': romPreambleHash,
        'recordedAt': recordedAt.millisecondsSinceEpoch,
      };

  static EcuFingerprint fromJson(Map<String, dynamic> j) => EcuFingerprint(
        ecuId: j['ecuId'] as String,
        partNumber: j['partNumber'] as String?,
        hardwareVersion: j['hardwareVersion'] as String?,
        softwareVersion: j['softwareVersion'] as String?,
        calibrationId: j['calibrationId'] as String?,
        romPreambleHash: j['romPreambleHash'] as String?,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(j['recordedAt'] as int),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _decodeAscii(List<int> bytes) {
    return String.fromCharCodes(bytes.where((b) => b >= 0x20 && b < 0x7F));
  }

  static String _hash(String input) {
    var h = 0x811C9DC5;
    for (final ch in input.codeUnits) {
      h ^= ch;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static String _hashBytes(Uint8List bytes) {
    var h = 0x811C9DC5;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

// ── Fingerprint mismatch exception ────────────────────────────────────────────

/// Thrown when attempting to apply a ROM or preset that was validated against
/// a different physical ECU unit (fingerprint mismatch).
class FingerprintMismatchException implements Exception {
  final String message;
  final String expectedHash;
  final String actualHash;

  const FingerprintMismatchException({
    required this.message,
    required this.expectedHash,
    required this.actualHash,
  });

  @override
  String toString() =>
      'FingerprintMismatchException: $message '
      '(expected: $expectedHash, actual: $actualHash)';
}

// ── Fingerprint store extension on EcuVerificationManager ─────────────────────

extension FingerprintStore on EcuVerificationManager {
  static final Map<String, EcuFingerprint> _fingerprints = {};

  /// Store a fingerprint for [ecuId].
  void storeFingerprint(String ecuId, EcuFingerprint fingerprint) {
    _fingerprints[ecuId] = fingerprint;
  }

  /// Retrieve the stored fingerprint for [ecuId], or null.
  EcuFingerprint? fingerprintFor(String ecuId) => _fingerprints[ecuId];

  /// Returns true if [candidate] matches the stored fingerprint for its ecuId.
  ///
  /// If no fingerprint is stored yet, returns true and saves [candidate].
  bool verifyOrStoreFingerprint(EcuFingerprint candidate) {
    final stored = _fingerprints[candidate.ecuId];
    if (stored == null) {
      _fingerprints[candidate.ecuId] = candidate;
      return true;
    }
    return stored.fingerprintHash == candidate.fingerprintHash;
  }
}
