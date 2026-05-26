import 'dart:typed_data';
import '../ecu/ecu_definition.dart';

class RomParseException implements Exception {
  final String message;
  const RomParseException(this.message);
  @override
  String toString() => 'RomParseException: $message';
}

/// A single extracted map region with physical values.
class ExtractedMap {
  /// The map descriptor this was extracted from.
  final MapDescriptor descriptor;

  /// Physical values as a rows×cols 2-D list.
  final List<List<double>> values;

  const ExtractedMap({required this.descriptor, required this.values});

  /// Get a single cell value.
  double cell(int row, int col) => values[row][col];

  /// Set a cell value (returns a new ExtractedMap with the cell updated).
  ExtractedMap withCell(int row, int col, double value) {
    final newValues = [
      for (int r = 0; r < values.length; r++)
        [
          for (int c = 0; c < values[r].length; c++)
            (r == row && c == col) ? value : values[r][c],
        ],
    ];
    return ExtractedMap(descriptor: descriptor, values: newValues);
  }

  /// Clamp all values to the descriptor's safe range.
  ExtractedMap clamped() {
    final d = descriptor;
    return ExtractedMap(
      descriptor: d,
      values: [
        for (final row in values)
          [for (final v in row) v.clamp(d.safeMin, d.safeMax).toDouble()],
      ],
    );
  }
}

/// Parsed ROM: all extracted maps from a raw ROM binary.
class ParsedRom {
  final EcuDefinition ecu;
  final Uint8List raw;
  final Map<String, ExtractedMap> maps;

  const ParsedRom({
    required this.ecu,
    required this.raw,
    required this.maps,
  });

  ExtractedMap? mapByName(String name) => maps[name];
}

/// Parses a raw ECU ROM binary into structured, editable maps.
///
/// Uses the [EcuDefinition.maps] to locate and decode each map region.
/// Validates that all map offsets are within the ROM bounds.
class RomBinaryParser {
  RomBinaryParser._();

  /// Parse [rom] according to the [ecu] map definitions.
  ///
  /// Throws [RomParseException] if [rom.length] != [ecu.romSizeBytes], or if
  /// any map descriptor's region exceeds the ROM bounds.
  static ParsedRom parseRom(Uint8List rom, EcuDefinition ecu) {
    if (rom.length != ecu.romSizeBytes) {
      throw RomParseException(
        'ROM size mismatch: expected ${ecu.romSizeBytes} bytes, '
        'got ${rom.length} bytes',
      );
    }

    final extractedMaps = <String, ExtractedMap>{};

    for (final desc in ecu.maps) {
      final endOffset = desc.romOffset + desc.cellCount;
      if (endOffset > rom.length) {
        throw RomParseException(
          'Map "${desc.name}" exceeds ROM bounds: '
          'offset 0x${desc.romOffset.toRadixString(16)} + '
          '${desc.cellCount} bytes > ${rom.length}',
        );
      }
      extractedMaps[desc.name] = _extractMap(rom, desc);
    }

    return ParsedRom(ecu: ecu, raw: rom, maps: extractedMaps);
  }

  static ExtractedMap _extractMap(Uint8List rom, MapDescriptor desc) {
    final values = <List<double>>[];
    int offset = desc.romOffset;

    for (int r = 0; r < desc.rows; r++) {
      final row = <double>[];
      for (int c = 0; c < desc.cols; c++) {
        row.add(desc.rawToPhysical(rom[offset++]));
      }
      values.add(row);
    }

    return ExtractedMap(descriptor: desc, values: values);
  }
}
