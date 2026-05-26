import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_remap_app/core/binary/rom_integrity_checker.dart';
import 'package:motorcycle_remap_app/core/ecu/ecu_fingerprint.dart';
import 'package:motorcycle_remap_app/core/ecu/ecu_registry.dart';

void main() {
  // ── RomIntegrityChecker ────────────────────────────────────────────────────

  group('RomIntegrityChecker', () {
    final ecu = EcuRegistry.hondaClick125i;

    test('1. valid ROM passes — correct size, normal entropy', () {
      final rom = _makeSyntheticRom(ecu.romSizeBytes);
      final result = RomIntegrityChecker.check(rom, ecu);
      expect(result.passed, isTrue,
          reason: 'Synthetic ROM with varied data should pass all checks');
      expect(result.issues.where((i) => i.blocksOperation), isEmpty);
    });

    test('2. all-zeros ROM is blocked', () {
      final rom = Uint8List(ecu.romSizeBytes); // filled with 0x00
      final result = RomIntegrityChecker.check(rom, ecu);
      expect(result.passed, isFalse);
      expect(result.issues.any((i) => i.fault == IntegrityFault.allZeros), isTrue);
      expect(result.hasBlockingFaults, isTrue);
    });

    test('3. all-0xFF ROM is blocked (erased flash)', () {
      final rom = Uint8List(ecu.romSizeBytes)..fillRange(0, ecu.romSizeBytes, 0xFF);
      final result = RomIntegrityChecker.check(rom, ecu);
      expect(result.passed, isFalse);
      expect(result.issues.any((i) => i.fault == IntegrityFault.allOnes), isTrue);
    });

    test('4. wrong size is blocked', () {
      final rom = Uint8List(512); // too small
      final result = RomIntegrityChecker.check(rom, ecu);
      expect(result.passed, isFalse);
      expect(result.issues.any((i) => i.fault == IntegrityFault.wrongSize), isTrue);
    });

    test('5. low-entropy ROM (repeated pattern) is blocked', () {
      final rom = Uint8List(ecu.romSizeBytes);
      // Repeating 2-byte pattern → very low entropy
      for (var i = 0; i < rom.length; i++) {
        rom[i] = (i % 2 == 0) ? 0xAA : 0x55;
      }
      final result = RomIntegrityChecker.check(rom, ecu);
      expect(result.passed, isFalse);
      expect(result.issues.any((i) => i.fault == IntegrityFault.lowEntropy), isTrue);
    });

    test('6. entropy value is non-zero for varied data', () {
      final rom = _makeSyntheticRom(ecu.romSizeBytes);
      final result = RomIntegrityChecker.check(rom, ecu);
      // Real ECU ROM typically measures 4.5–7.5 bits/byte. Our minimum threshold
      // is 3.5 — so any genuine ROM data should be well above it.
      expect(result.entropyBitsPerByte, greaterThan(3.5));
    });

    test('7. unique byte count is reported', () {
      final rom = _makeSyntheticRom(ecu.romSizeBytes);
      final result = RomIntegrityChecker.check(rom, ecu);
      expect(result.uniqueByteCount, greaterThan(20));
    });

    test('8. no ECU size constraint — size check skipped when romSizeBytes=0', () {
      final ecu0 = EcuRegistry.all.firstWhere((e) => e.romSizeBytes == 0,
          orElse: () => ecu);
      if (ecu0.romSizeBytes == 0) {
        final rom = _makeSyntheticRom(1024);
        final result = RomIntegrityChecker.check(rom, ecu0);
        expect(result.issues.any((i) => i.fault == IntegrityFault.wrongSize),
            isFalse,
            reason: 'Size check skipped when romSizeBytes==0');
      }
    });
  });

  // ── EcuFingerprint ─────────────────────────────────────────────────────────

  group('EcuFingerprint', () {
    test('9. fromIdentification builds fingerprint correctly', () {
      final fp = EcuFingerprint.fromIdentification(
        ecuId: 'honda_click_125i',
        record87PartNumber: '37820-KYZ-N01'.codeUnits,
        record88HardwareVersion: 'HW-A01'.codeUnits,
        record89SoftwareVersion: 'SW-1.04'.codeUnits,
      );
      expect(fp.partNumber, '37820-KYZ-N01');
      expect(fp.hardwareVersion, 'HW-A01');
      expect(fp.softwareVersion, 'SW-1.04');
      expect(fp.ecuId, 'honda_click_125i');
    });

    test('10. fingerprintHash is stable — same inputs produce same hash', () {
      final fp1 = EcuFingerprint.fromIdentification(
        ecuId: 'honda_click_125i',
        record87PartNumber: 'PART-A'.codeUnits,
        record89SoftwareVersion: 'SW-1.00'.codeUnits,
      );
      final fp2 = EcuFingerprint.fromIdentification(
        ecuId: 'honda_click_125i',
        record87PartNumber: 'PART-A'.codeUnits,
        record89SoftwareVersion: 'SW-1.00'.codeUnits,
      );
      expect(fp1.fingerprintHash, fp2.fingerprintHash);
    });

    test('11. different SW versions produce different fingerprints', () {
      final fp1 = EcuFingerprint.fromIdentification(
        ecuId: 'honda_click_125i',
        record89SoftwareVersion: 'SW-1.00'.codeUnits,
      );
      final fp2 = EcuFingerprint.fromIdentification(
        ecuId: 'honda_click_125i',
        record89SoftwareVersion: 'SW-1.05'.codeUnits,
      );
      expect(fp1.fingerprintHash, isNot(fp2.fingerprintHash));
    });

    test('12. shortId falls back to ecuId when no records available', () {
      final fp = EcuFingerprint.fromIdentification(ecuId: 'honda_click_125i');
      expect(fp.shortId, 'honda_click_125i');
    });

    test('13. shortId includes part number and SW version when available', () {
      final fp = EcuFingerprint.fromIdentification(
        ecuId: 'honda_click_125i',
        record87PartNumber: 'PART-X'.codeUnits,
        record89SoftwareVersion: 'SW-1.00'.codeUnits,
      );
      expect(fp.shortId, contains('PART-X'));
      expect(fp.shortId, contains('SW-1.00'));
    });

    test('14. toJson / fromJson round-trip preserves all fields', () {
      final original = EcuFingerprint.fromIdentification(
        ecuId: 'yamaha_aerox_155',
        record87PartNumber: 'AEROX-PART'.codeUnits,
        record89SoftwareVersion: 'FW-2.10'.codeUnits,
        romPreamble: Uint8List.fromList([0x1F, 0x3E, 0xA7, 0x00]),
      );
      final json = original.toJson();
      final restored = EcuFingerprint.fromJson(json);
      expect(restored.ecuId, original.ecuId);
      expect(restored.partNumber, original.partNumber);
      expect(restored.softwareVersion, original.softwareVersion);
      expect(restored.romPreambleHash, original.romPreambleHash);
    });

    test('15. romPreamble hash differs from no-preamble fingerprint', () {
      final withPreamble = EcuFingerprint.fromIdentification(
        ecuId: 'honda_click_125i',
        romPreamble: Uint8List.fromList([0x01, 0x02, 0x03]),
      );
      final noPreamble = EcuFingerprint.fromIdentification(
        ecuId: 'honda_click_125i',
      );
      // fingerprintHash does NOT include preamble (intentional — survives reflash)
      expect(withPreamble.fingerprintHash, noPreamble.fingerprintHash);
      // But romPreambleHash is set
      expect(withPreamble.romPreambleHash, isNotNull);
      expect(noPreamble.romPreambleHash, isNull);
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Build a ROM filled with pseudo-random bytes derived from position.
/// Produces high-entropy data that passes integrity checks.
Uint8List _makeSyntheticRom(int size) {
  final rom = Uint8List(size);
  var seed = 0xA3;
  for (var i = 0; i < size; i++) {
    seed = ((seed * 0x41C64E6D) + 0x3039) & 0xFF;
    rom[i] = seed ^ (i & 0xFF);
  }
  return rom;
}
