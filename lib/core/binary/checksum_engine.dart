import 'dart:typed_data';
import '../ecu/ecu_definition.dart';

class ChecksumMismatchException implements Exception {
  final String message;
  const ChecksumMismatchException(this.message);
  @override
  String toString() => 'ChecksumMismatchException: $message';
}

/// Verifies and corrects ECU ROM checksums.
///
/// Supported algorithms:
/// - [ChecksumAlgorithm.additiveByte] — sum of bytes mod 256, stored as 1 byte
/// - [ChecksumAlgorithm.additiveWord] — sum of bytes mod 65536, stored as 2 bytes LE
/// - [ChecksumAlgorithm.crc16]        — CRC-16/IBM (poly 0x8005, reflect in/out)
/// - [ChecksumAlgorithm.keihinCustom] — Honda Keihin variant of additiveByte
/// - [ChecksumAlgorithm.shindengenCustom] — Shindengen variant of CRC16
class ChecksumEngine {
  ChecksumEngine._();

  /// Verify the ROM checksum. Returns true if valid.
  static bool verify(Uint8List rom, ChecksumDescriptor desc) {
    final computed = _compute(rom, desc);
    final stored = _readStored(rom, desc);
    return computed == stored;
  }

  /// Return a new ROM with the checksum field corrected.
  ///
  /// Does NOT modify [rom]. Returns a new [Uint8List].
  static Uint8List correct(Uint8List rom, ChecksumDescriptor desc) {
    final result = Uint8List.fromList(rom);
    final computed = _compute(result, desc);
    _writeChecksum(result, desc, computed);
    return result;
  }

  // ── Algorithm dispatch ────────────────────────────────────────────────────

  static int _compute(Uint8List rom, ChecksumDescriptor desc) {
    return switch (desc.algorithm) {
      ChecksumAlgorithm.additiveByte => _additiveByte(rom, desc),
      ChecksumAlgorithm.additiveWord => _additiveWord(rom, desc),
      ChecksumAlgorithm.crc16 => _crc16(rom, desc),
      ChecksumAlgorithm.keihinCustom => _keihinCustom(rom, desc),
      ChecksumAlgorithm.shindengenCustom => _shindengenCustom(rom, desc),
    };
  }

  // ── additiveByte ──────────────────────────────────────────────────────────

  /// Sum of all bytes in [startOffset, endOffset) mod 256.
  /// Stored as a single byte at [checksumOffset].
  static int _additiveByte(Uint8List rom, ChecksumDescriptor desc) {
    int sum = 0;
    for (int i = desc.startOffset; i < desc.endOffset; i++) {
      sum = (sum + rom[i]) & 0xFF;
    }
    return sum;
  }

  // ── additiveWord ──────────────────────────────────────────────────────────

  /// 16-bit additive sum of all bytes mod 65536.
  /// Stored as little-endian 16-bit value at [checksumOffset].
  static int _additiveWord(Uint8List rom, ChecksumDescriptor desc) {
    int sum = 0;
    for (int i = desc.startOffset; i < desc.endOffset; i++) {
      sum = (sum + rom[i]) & 0xFFFF;
    }
    return sum;
  }

  // ── CRC-16/IBM ────────────────────────────────────────────────────────────

  static final List<int> _crc16Table = _buildCrc16Table();

  static List<int> _buildCrc16Table() {
    const poly = 0x8005;
    final table = List.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int j = 0; j < 8; j++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ poly : crc >> 1;
      }
      table[i] = crc & 0xFFFF;
    }
    return table;
  }

  /// CRC-16/IBM: reflected in/out, initial value 0x0000.
  static int _crc16(Uint8List rom, ChecksumDescriptor desc) {
    int crc = 0x0000;
    for (int i = desc.startOffset; i < desc.endOffset; i++) {
      final byte = rom[i];
      crc = (_crc16Table[(crc ^ byte) & 0xFF] ^ (crc >> 8)) & 0xFFFF;
    }
    return crc;
  }

  // ── Keihin custom ─────────────────────────────────────────────────────────

  /// Honda Keihin custom: additiveByte with one's complement of result.
  /// Checksum byte at [checksumOffset] should equal (~sum) & 0xFF such that
  /// sum(all bytes including checksum byte) == 0x00.
  static int _keihinCustom(Uint8List rom, ChecksumDescriptor desc) {
    int sum = 0;
    for (int i = desc.startOffset; i < desc.endOffset; i++) {
      sum = (sum + rom[i]) & 0xFF;
    }
    // The checksum byte = two's complement (0 - sum) & 0xFF
    return (0x100 - sum) & 0xFF;
  }

  // ── Shindengen custom ─────────────────────────────────────────────────────

  /// Shindengen custom: CRC-16 with initial value 0xFFFF.
  static int _shindengenCustom(Uint8List rom, ChecksumDescriptor desc) {
    int crc = 0xFFFF;
    for (int i = desc.startOffset; i < desc.endOffset; i++) {
      final byte = rom[i];
      crc = (_crc16Table[(crc ^ byte) & 0xFF] ^ (crc >> 8)) & 0xFFFF;
    }
    return crc ^ 0xFFFF; // final XOR
  }

  // ── Read/write stored checksum ────────────────────────────────────────────

  static int _readStored(Uint8List rom, ChecksumDescriptor desc) {
    return switch (desc.algorithm) {
      ChecksumAlgorithm.additiveWord ||
      ChecksumAlgorithm.crc16 ||
      ChecksumAlgorithm.shindengenCustom =>
        // 16-bit little-endian
        rom[desc.checksumOffset] | (rom[desc.checksumOffset + 1] << 8),
      _ =>
        // Single byte
        rom[desc.checksumOffset],
    };
  }

  static void _writeChecksum(
    Uint8List rom,
    ChecksumDescriptor desc,
    int value,
  ) {
    switch (desc.algorithm) {
      case ChecksumAlgorithm.additiveWord:
      case ChecksumAlgorithm.crc16:
      case ChecksumAlgorithm.shindengenCustom:
        // 16-bit little-endian
        rom[desc.checksumOffset] = value & 0xFF;
        rom[desc.checksumOffset + 1] = (value >> 8) & 0xFF;
      default:
        // Single byte
        rom[desc.checksumOffset] = value & 0xFF;
    }
  }
}
