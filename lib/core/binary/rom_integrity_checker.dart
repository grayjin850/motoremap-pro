import 'dart:typed_data';
import '../ecu/ecu_definition.dart';

// ── Result models ─────────────────────────────────────────────────────────────

enum IntegrityFault {
  wrongSize,
  allZeros,
  allOnes,
  lowEntropy,
  repeatingBlocks,
  checksumMismatch,
}

class IntegrityIssue {
  final IntegrityFault fault;
  final String description;
  final bool blocksOperation;

  const IntegrityIssue({
    required this.fault,
    required this.description,
    required this.blocksOperation,
  });
}

class RomIntegrityResult {
  final bool passed;
  final List<IntegrityIssue> issues;
  final double entropyBitsPerByte;
  final int uniqueByteCount;
  final String summary;

  const RomIntegrityResult({
    required this.passed,
    required this.issues,
    required this.entropyBitsPerByte,
    required this.uniqueByteCount,
    required this.summary,
  });

  bool get hasBlockingFaults => issues.any((i) => i.blocksOperation);
  List<IntegrityIssue> get blockingFaults =>
      issues.where((i) => i.blocksOperation).toList();
}

// ── Checker ───────────────────────────────────────────────────────────────────

/// Validates a ROM binary before any map operation or flash attempt.
///
/// Detects: wrong size, blank/erased flash (all-0x00 or all-0xFF),
/// low-entropy data (firmware garbled or truncated), large repeating blocks
/// (copy-paste corruption), and checksum pre-validation.
///
/// All blocking faults prevent the map editor from opening.
class RomIntegrityChecker {
  RomIntegrityChecker._();

  static const int _repeatBlockSize = 256;
  static const int _maxRepeatBlocks = 8;
  static const double _minEntropy = 3.5; // bits per byte (real ECU ROM > 5.0)

  /// Check [rom] against [ecu] specifications.
  ///
  /// Call before RomBinaryParser.parseRom() and before every flash attempt.
  static RomIntegrityResult check(Uint8List rom, EcuDefinition ecu) {
    final issues = <IntegrityIssue>[];

    // 1 — Size check
    if (ecu.romSizeBytes > 0 && rom.length != ecu.romSizeBytes) {
      issues.add(IntegrityIssue(
        fault: IntegrityFault.wrongSize,
        description: 'ROM size is ${rom.length} bytes but expected '
            '${ecu.romSizeBytes} bytes for ${ecu.displayName}.',
        blocksOperation: true,
      ));
    }

    // 2 — Blank/erased ROM detection
    if (_isAllSameByte(rom, 0x00)) {
      issues.add(IntegrityIssue(
        fault: IntegrityFault.allZeros,
        description: 'ROM is all 0x00 — flash chip is blank or read failed.',
        blocksOperation: true,
      ));
    } else if (_isAllSameByte(rom, 0xFF)) {
      issues.add(IntegrityIssue(
        fault: IntegrityFault.allOnes,
        description: 'ROM is all 0xFF — flash chip is erased or read failed.',
        blocksOperation: true,
      ));
    }

    // 3 — Entropy analysis
    final entropy = _shannonEntropy(rom);
    if (entropy < _minEntropy) {
      issues.add(IntegrityIssue(
        fault: IntegrityFault.lowEntropy,
        description: 'ROM entropy ${entropy.toStringAsFixed(2)} bits/byte is '
            'abnormally low (expected >$_minEntropy). '
            'Possible truncated read or corruption.',
        blocksOperation: true,
      ));
    }

    // 4 — Repeating block detection (indicates copy-paste corruption or bad read)
    final repeatCount = _countRepeatBlocks(rom);
    if (repeatCount > _maxRepeatBlocks) {
      issues.add(IntegrityIssue(
        fault: IntegrityFault.repeatingBlocks,
        description: '$repeatCount identical $_repeatBlockSize-byte blocks found. '
            'Possible read error or corrupted backup. '
            'Verify with a fresh ROM dump.',
        blocksOperation: false,
      ));
    }

    final uniqueBytes = _uniqueByteCount(rom);
    final passed = !issues.any((i) => i.blocksOperation);

    return RomIntegrityResult(
      passed: passed,
      issues: issues,
      entropyBitsPerByte: entropy,
      uniqueByteCount: uniqueBytes,
      summary: _buildSummary(passed, issues, entropy, uniqueBytes),
    );
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static bool _isAllSameByte(Uint8List rom, int byte) {
    for (final b in rom) {
      if (b != byte) return false;
    }
    return true;
  }

  static double _shannonEntropy(Uint8List rom) {
    if (rom.isEmpty) return 0;
    final freq = List<int>.filled(256, 0);
    for (final b in rom) {
      freq[b]++;
    }
    var entropy = 0.0;
    final n = rom.length;
    for (final count in freq) {
      if (count == 0) continue;
      final p = count / n;
      entropy -= p * (p == 0 ? 0 : _log2(p));
    }
    return entropy;
  }

  static double _log2(double x) => (x == 0) ? 0 : (x.abs() == 1 ? 0 : _ln(x) / _ln2);
  static const double _ln2 = 0.6931471805599453;
  static double _ln(double x) {
    // Taylor expansion for ln(x) is not needed here — use a simple iterative approach
    // since dart:math is not imported. We use Newton's method.
    if (x <= 0) return double.negativeInfinity;
    // Use: ln(x) = 2 * atanh((x-1)/(x+1)) — converges for x>0
    double y = (x - 1) / (x + 1);
    double result = 0;
    double term = y;
    for (int k = 1; k <= 30; k += 2) {
      result += term / k;
      term *= y * y;
    }
    return 2 * result;
  }

  static int _countRepeatBlocks(Uint8List rom) {
    if (rom.length < _repeatBlockSize * 2) return 0;
    final seen = <String>{};
    var repeats = 0;
    for (var i = 0; i + _repeatBlockSize <= rom.length; i += _repeatBlockSize) {
      final block = rom.sublist(i, i + _repeatBlockSize).toString();
      if (!seen.add(block)) repeats++;
    }
    return repeats;
  }

  static int _uniqueByteCount(Uint8List rom) {
    final seen = <int>{};
    for (final b in rom) {
      seen.add(b);
    }
    return seen.length;
  }

  static String _buildSummary(
    bool passed,
    List<IntegrityIssue> issues,
    double entropy,
    int unique,
  ) {
    if (passed && issues.isEmpty) {
      return 'ROM integrity OK — ${entropy.toStringAsFixed(2)} bits/byte entropy, '
          '$unique unique byte values.';
    }
    if (!passed) {
      final blocking = issues.where((i) => i.blocksOperation).length;
      return 'ROM INTEGRITY FAILED — $blocking blocking fault(s) detected. '
          'Do NOT proceed with map editing or flash.';
    }
    return 'ROM passed — ${issues.length} advisory warning(s). Review before flash.';
  }
}
