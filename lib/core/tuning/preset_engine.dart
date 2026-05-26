import 'dart:typed_data';
import '../binary/rom_parser.dart';
import '../binary/rom_writer.dart';
import '../binary/checksum_engine.dart';
import '../ecu/ecu_definition.dart';
import 'tune_preset.dart';

/// Applies a [TunePreset] to a ROM image, returning a modified + checksum-corrected copy.
class PresetEngine {
  PresetEngine._();

  /// Apply [preset] to [rom] for [ecu].
  ///
  /// Returns an [AppliedPresetResult] containing:
  /// - [modifiedRom]: the patched ROM with corrected checksum
  /// - [appliedDeltas]: how many cells were actually changed
  /// - [clampedCells]: cells where values hit safeMin/safeMax
  ///
  /// Throws [PresetEngineMismatchException] if the preset's ecuId doesn't match.
  static AppliedPresetResult apply({
    required Uint8List originalRom,
    required ParsedRom parsedRom,
    required TunePreset preset,
    required EcuDefinition ecu,
  }) {
    if (preset.ecuId != ecu.id) {
      throw PresetEngineMismatchException(
        'Preset "${preset.id}" targets ECU "${preset.ecuId}" '
        'but connected ECU is "${ecu.id}"',
      );
    }

    var rom = Uint8List.fromList(originalRom); // work on a copy
    var applied = 0;
    var clamped = 0;

    for (final delta in preset.deltas) {
      final extractedMap = parsedRom.maps[delta.mapName];
      final descriptor = ecu.mapByName(delta.mapName);
      if (extractedMap == null || descriptor == null) continue;

      for (var r = delta.rpmRowLow; r <= delta.rpmRowHigh; r++) {
        if (r >= descriptor.rows) break;
        for (var c = delta.tpsColLow; c <= delta.tpsColHigh; c++) {
          if (c >= descriptor.cols) break;

          final original = extractedMap.values[r][c];
          final proposed = delta.applyTo(original);

          // Clamp to map safe limits
          final clamped_ = proposed.clamp(descriptor.safeMin, descriptor.safeMax);
          if (clamped_ != proposed) clamped++;

          // Only write if value actually changed
          if ((clamped_ - original).abs() > 0.001) {
            rom = RomBinaryWriter.applyCell(rom, descriptor, r, c, clamped_);
            applied++;
          }
        }
      }
    }

    // Correct checksum in the modified ROM
    if (ecu.checksumDescriptor != null) {
      rom = ChecksumEngine.correct(rom, ecu.checksumDescriptor!);
    }

    return AppliedPresetResult(
      modifiedRom: rom,
      appliedDeltaCount: applied,
      clampedCellCount: clamped,
    );
  }
}

class AppliedPresetResult {
  final Uint8List modifiedRom;
  final int appliedDeltaCount;
  final int clampedCellCount;

  const AppliedPresetResult({
    required this.modifiedRom,
    required this.appliedDeltaCount,
    required this.clampedCellCount,
  });
}

class PresetEngineMismatchException implements Exception {
  final String message;
  const PresetEngineMismatchException(this.message);
  @override
  String toString() => 'PresetEngineMismatchException: $message';
}
