import 'dart:typed_data';
import '../ecu/ecu_definition.dart';

/// A single byte difference between the original and modified ROM.
class RomDiff {
  /// Byte offset within the ROM.
  final int offset;

  /// Original byte value.
  final int originalByte;

  /// Modified byte value.
  final int newByte;

  const RomDiff({
    required this.offset,
    required this.originalByte,
    required this.newByte,
  });

  @override
  String toString() =>
      '0x${offset.toRadixString(16).padLeft(4, "0")}: '
      '0x${originalByte.toRadixString(16).padLeft(2, "0")} → '
      '0x${newByte.toRadixString(16).padLeft(2, "0")}';
}

/// A group of diffs that fall within a named map region.
class MapDiff {
  /// Map name from [MapDescriptor.name].
  final String mapName;

  /// All changed bytes within this map region.
  final List<RomDiff> diffs;

  const MapDiff({required this.mapName, required this.diffs});

  int get changeCount => diffs.length;
}

/// Result of comparing two ROM binaries.
class DiffResult {
  /// All changed bytes, in offset order.
  final List<RomDiff> allDiffs;

  /// Diffs grouped by the map they fall within.
  /// Diffs outside any known map are in [unmappedDiffs].
  final List<MapDiff> mapDiffs;

  /// Diffs that don't fall within any known map region.
  final List<RomDiff> unmappedDiffs;

  const DiffResult({
    required this.allDiffs,
    required this.mapDiffs,
    required this.unmappedDiffs,
  });

  int get totalChanges => allDiffs.length;
  bool get isEmpty => allDiffs.isEmpty;
}

/// Computes the minimum diff between two ROM binaries.
///
/// Only changed bytes are listed — unchanged bytes are not reported.
/// Diffs are grouped by the map region they fall within (if a known
/// [EcuDefinition] is provided), making it easy to show the user which
/// maps changed before they approve a flash.
class RomDiffEngine {
  RomDiffEngine._();

  /// Compute the diff between [original] and [modified].
  ///
  /// If [ecu] is provided, diffs are grouped by map descriptor.
  /// Both ROMs must be the same length.
  static DiffResult diff(
    Uint8List original,
    Uint8List modified, {
    EcuDefinition? ecu,
  }) {
    if (original.length != modified.length) {
      throw ArgumentError(
        'ROM size mismatch: ${original.length} vs ${modified.length}',
      );
    }

    final allDiffs = <RomDiff>[];
    for (int i = 0; i < original.length; i++) {
      if (original[i] != modified[i]) {
        allDiffs.add(RomDiff(
          offset: i,
          originalByte: original[i],
          newByte: modified[i],
        ));
      }
    }

    if (ecu == null) {
      return DiffResult(
        allDiffs: allDiffs,
        mapDiffs: const [],
        unmappedDiffs: allDiffs,
      );
    }

    return _groupByMap(allDiffs, ecu);
  }

  static DiffResult _groupByMap(List<RomDiff> allDiffs, EcuDefinition ecu) {
    final mapDiffs = <MapDiff>[];
    final assignedOffsets = <int>{};

    for (final desc in ecu.maps) {
      final mapStart = desc.romOffset;
      final mapEnd = desc.romOffset + desc.cellCount;

      final inMap = allDiffs
          .where((d) => d.offset >= mapStart && d.offset < mapEnd)
          .toList();

      if (inMap.isNotEmpty) {
        mapDiffs.add(MapDiff(mapName: desc.name, diffs: inMap));
        for (final d in inMap) {
          assignedOffsets.add(d.offset);
        }
      }
    }

    final unmapped =
        allDiffs.where((d) => !assignedOffsets.contains(d.offset)).toList();

    return DiffResult(
      allDiffs: allDiffs,
      mapDiffs: mapDiffs,
      unmappedDiffs: unmapped,
    );
  }
}
