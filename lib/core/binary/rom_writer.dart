import 'dart:typed_data';
import '../ecu/ecu_definition.dart';
import 'rom_parser.dart';

/// Writes map edits back into a ROM binary, clamped to safe limits.
///
/// Applies the minimum change principle: only cells that differ from the
/// original are written. Returns a new [Uint8List] — never mutates the input.
class RomBinaryWriter {
  RomBinaryWriter._();

  /// Apply [newValues] for [map] into [rom].
  ///
  /// [newValues] is a rows×cols grid of physical values.
  /// Values are inverse-scaled to raw bytes via [MapDescriptor.physicalToRaw],
  /// then clamped to the descriptor's safe range.
  ///
  /// Returns a new [Uint8List] with only the edited cells changed.
  static Uint8List applyMapEdit(
    Uint8List rom,
    MapDescriptor map,
    List<List<double>> newValues,
  ) {
    final result = Uint8List.fromList(rom);
    int offset = map.romOffset;

    for (int r = 0; r < map.rows; r++) {
      for (int c = 0; c < map.cols; c++) {
        final physical = newValues[r][c].clamp(map.safeMin, map.safeMax);
        result[offset++] = map.physicalToRaw(physical.toDouble());
      }
    }

    return result;
  }

  /// Apply a single cell edit, leaving all other cells unchanged.
  static Uint8List applyCell(
    Uint8List rom,
    MapDescriptor map,
    int row,
    int col,
    double physicalValue,
  ) {
    final clamped = physicalValue.clamp(map.safeMin, map.safeMax).toDouble();
    final cellOffset = map.romOffset + (row * map.cols) + col;

    final result = Uint8List.fromList(rom);
    result[cellOffset] = map.physicalToRaw(clamped);
    return result;
  }

  /// Apply an [ExtractedMap]'s current values back into [rom].
  static Uint8List applyExtractedMap(Uint8List rom, ExtractedMap extracted) {
    return applyMapEdit(rom, extracted.descriptor, extracted.values);
  }
}
