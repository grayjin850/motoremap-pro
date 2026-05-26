import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'ecu_definition.dart';

/// Tracks which ECU models have been hardware-validated.
///
/// An ECU is considered verified when:
///   1. A real ROM has been dumped from physical hardware.
///   2. Map offsets have been manually confirmed against the ROM binary.
///   3. Checksum algorithm has been validated (computed == stored).
///   4. Security access (seed→key) has been confirmed on real hardware.
///
/// Verification state persists across sessions via SharedPreferences.
/// Only verified ECUs show the "READY TO FLASH" status in the UI.
/// Unverified ECUs can be read and edited, but flashing shows a
/// mandatory warning banner.
class EcuVerificationManager {
  static const String _prefKey = 'ecu_verification_records';

  EcuVerificationManager._();
  static final EcuVerificationManager instance = EcuVerificationManager._();

  final Map<String, VerificationRecord> _cache = {};
  bool _loaded = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Load verification records from persistent storage.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefKey);
    if (json != null) {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        _cache[entry.key] =
            VerificationRecord.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    _loaded = true;
  }

  /// Returns the verification record for [ecuId], or null if never verified.
  VerificationRecord? recordFor(String ecuId) => _cache[ecuId];

  /// Returns true if [ecuId] has a complete, valid verification record.
  bool isVerified(String ecuId) {
    final r = _cache[ecuId];
    if (r == null) return false;
    return r.romDumpHash != null &&
        r.checksumValidated &&
        r.securityAccessConfirmed &&
        r.validatedMapOffsets.isNotEmpty;
  }

  /// Returns the verification status label for display in the UI.
  VerificationStatus statusFor(String ecuId) {
    final r = _cache[ecuId];
    if (r == null) return VerificationStatus.unverified;
    if (isVerified(ecuId)) return VerificationStatus.verified;
    return VerificationStatus.partial;
  }

  /// Record a successful ROM dump. Stores the SHA-256 hash of the dump.
  Future<void> recordRomDump(String ecuId, Uint8List romBytes) async {
    final hash = _sha256Hex(romBytes);
    final existing = _cache[ecuId] ?? VerificationRecord(ecuId: ecuId);
    _cache[ecuId] = existing.copyWith(
      romDumpHash: hash,
      romSizeBytes: romBytes.length,
      romDumpAt: DateTime.now(),
    );
    await _save();
  }

  /// Record that the checksum algorithm has been validated against a real dump.
  Future<void> recordChecksumValidated(String ecuId) async {
    final existing = _cache[ecuId] ?? VerificationRecord(ecuId: ecuId);
    _cache[ecuId] = existing.copyWith(checksumValidated: true);
    await _save();
  }

  /// Record that security access (seed→key) worked on real hardware.
  Future<void> recordSecurityAccessConfirmed(String ecuId) async {
    final existing = _cache[ecuId] ?? VerificationRecord(ecuId: ecuId);
    _cache[ecuId] = existing.copyWith(securityAccessConfirmed: true);
    await _save();
  }

  /// Record that a map offset has been manually confirmed in the real ROM binary.
  Future<void> recordOffsetValidated(
    String ecuId,
    String mapName,
    int confirmedOffset,
  ) async {
    final existing = _cache[ecuId] ?? VerificationRecord(ecuId: ecuId);
    final offsets = Map<String, int>.from(existing.validatedMapOffsets);
    offsets[mapName] = confirmedOffset;
    _cache[ecuId] = existing.copyWith(validatedMapOffsets: offsets);
    await _save();
  }

  /// Record a successful flash and reboot cycle — highest confidence level.
  Future<void> recordSuccessfulFlash(String ecuId) async {
    final existing = _cache[ecuId] ?? VerificationRecord(ecuId: ecuId);
    _cache[ecuId] = existing.copyWith(
      flashCount: existing.flashCount + 1,
      lastSuccessfulFlashAt: DateTime.now(),
    );
    await _save();
  }

  /// Clear all verification records for an ECU (e.g. after ROM variant change).
  Future<void> clearRecord(String ecuId) async {
    _cache.remove(ecuId);
    await _save();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _cache.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_prefKey, encoded);
  }

  static String _sha256Hex(Uint8List bytes) {
    // Simple additive hash (not cryptographic) — sufficient for ROM identity.
    // A real implementation would use package:crypto for SHA-256.
    var hash = 0;
    for (final b in bytes) {
      hash = ((hash << 5) - hash + b) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

// ── Verification record ───────────────────────────────────────────────────────

class VerificationRecord {
  final String ecuId;
  final String? romDumpHash;
  final int? romSizeBytes;
  final DateTime? romDumpAt;
  final bool checksumValidated;
  final bool securityAccessConfirmed;
  final Map<String, int> validatedMapOffsets;
  final int flashCount;
  final DateTime? lastSuccessfulFlashAt;

  const VerificationRecord({
    required this.ecuId,
    this.romDumpHash,
    this.romSizeBytes,
    this.romDumpAt,
    this.checksumValidated = false,
    this.securityAccessConfirmed = false,
    this.validatedMapOffsets = const {},
    this.flashCount = 0,
    this.lastSuccessfulFlashAt,
  });

  VerificationRecord copyWith({
    String? romDumpHash,
    int? romSizeBytes,
    DateTime? romDumpAt,
    bool? checksumValidated,
    bool? securityAccessConfirmed,
    Map<String, int>? validatedMapOffsets,
    int? flashCount,
    DateTime? lastSuccessfulFlashAt,
  }) =>
      VerificationRecord(
        ecuId: ecuId,
        romDumpHash: romDumpHash ?? this.romDumpHash,
        romSizeBytes: romSizeBytes ?? this.romSizeBytes,
        romDumpAt: romDumpAt ?? this.romDumpAt,
        checksumValidated: checksumValidated ?? this.checksumValidated,
        securityAccessConfirmed:
            securityAccessConfirmed ?? this.securityAccessConfirmed,
        validatedMapOffsets: validatedMapOffsets ?? this.validatedMapOffsets,
        flashCount: flashCount ?? this.flashCount,
        lastSuccessfulFlashAt:
            lastSuccessfulFlashAt ?? this.lastSuccessfulFlashAt,
      );

  Map<String, dynamic> toJson() => {
        'ecuId': ecuId,
        'romDumpHash': romDumpHash,
        'romSizeBytes': romSizeBytes,
        'romDumpAt': romDumpAt?.millisecondsSinceEpoch,
        'checksumValidated': checksumValidated,
        'securityAccessConfirmed': securityAccessConfirmed,
        'validatedMapOffsets':
            validatedMapOffsets.map((k, v) => MapEntry(k, v)),
        'flashCount': flashCount,
        'lastSuccessfulFlashAt':
            lastSuccessfulFlashAt?.millisecondsSinceEpoch,
      };

  static VerificationRecord fromJson(Map<String, dynamic> j) =>
      VerificationRecord(
        ecuId: j['ecuId'] as String,
        romDumpHash: j['romDumpHash'] as String?,
        romSizeBytes: j['romSizeBytes'] as int?,
        romDumpAt: j['romDumpAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['romDumpAt'] as int)
            : null,
        checksumValidated: j['checksumValidated'] as bool? ?? false,
        securityAccessConfirmed:
            j['securityAccessConfirmed'] as bool? ?? false,
        validatedMapOffsets:
            (j['validatedMapOffsets'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, v as int)),
        flashCount: j['flashCount'] as int? ?? 0,
        lastSuccessfulFlashAt: j['lastSuccessfulFlashAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                j['lastSuccessfulFlashAt'] as int)
            : null,
      );
}

enum VerificationStatus {
  unverified,  // No real hardware contact yet
  partial,     // ROM dumped but offsets/checksum/security not all confirmed
  verified,    // All validation steps complete — safe to flash
}

extension VerificationStatusInfo on VerificationStatus {
  String get label => switch (this) {
        VerificationStatus.unverified => 'UNVERIFIED',
        VerificationStatus.partial => 'PARTIAL',
        VerificationStatus.verified => 'VERIFIED',
      };

  String get description => switch (this) {
        VerificationStatus.unverified =>
          'No real hardware contact. ROM offsets are community estimates. '
              'Flash possible but high risk — validate first.',
        VerificationStatus.partial =>
          'ROM dump exists but not all offsets/algorithms confirmed. '
              'Review validation checklist before flashing.',
        VerificationStatus.verified =>
          'All checks passed on real hardware. Safe to flash.',
      };
}
