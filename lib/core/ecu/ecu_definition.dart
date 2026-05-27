import '../protocols/adapter_interface.dart';

/// Supported ECU chip families.
enum EcuChipFamily {
  shindengenRh850, // Yamaha Aerox 155, NMAX 155 — Renesas RH850
  keihin,          // Honda Click 125i, CBR150R, CB150R — Keihin FI
  denso,           // Suzuki Raider R150 FI, GSX-S150 — Denso
  unknown,
}

/// Security access algorithm for KWP2000 service 0x27 seed→key exchange.
enum SecurityAlgorithm {
  none,            // No security access required
  keihinXor,       // Honda Keihin FI: XOR constants + 16-bit rotation
  shindengenRh850, // Yamaha Shindengen RH850: different XOR + rotation
}

/// Checksum algorithm for ROM integrity verification and correction.
enum ChecksumAlgorithm {
  additiveByte,    // Sum of all bytes mod 256, stored as single byte
  additiveWord,    // 16-bit additive sum
  crc16,           // CRC-16/IBM (polynomial 0x8005, reflects)
  keihinCustom,    // Honda Keihin proprietary checksum variant
  shindengenCustom, // Shindengen proprietary checksum variant
}

/// Describes a single tunable map region within the ECU ROM binary.
class MapDescriptor {
  /// Machine identifier used as a key throughout the app.
  final String name;

  /// Byte offset of the map's first cell within the ROM.
  final int romOffset;

  /// Number of rows (RPM axis).
  final int rows;

  /// Number of columns (load / TPS axis).
  final int cols;

  /// Scale factor: physicalValue = (rawByte × scale) + offset.
  final double scale;

  /// Bias offset: physicalValue = (rawByte × scale) + offset.
  final double offset;

  /// Physical unit string shown in the map editor (e.g. 'kg/h', 'deg BTDC').
  final String unit;

  /// Minimum safe physical value — SafetyValidator hard limit.
  final double safeMin;

  /// Maximum safe physical value — SafetyValidator hard limit.
  final double safeMax;

  const MapDescriptor({
    required this.name,
    required this.romOffset,
    required this.rows,
    required this.cols,
    required this.scale,
    required this.offset,
    required this.unit,
    required this.safeMin,
    required this.safeMax,
  });

  /// Total number of cells in this map.
  int get cellCount => rows * cols;

  /// Convert a raw ROM byte to a physical value.
  double rawToPhysical(int rawByte) => (rawByte * scale) + offset;

  /// Convert a physical value to a raw byte, clamped to [0, 255].
  int physicalToRaw(double value) =>
      ((value - offset) / scale).round().clamp(0, 255);
}

/// RPM and load axis labels for map display.
class AxisDescriptor {
  /// RPM breakpoints for the row axis (one entry per row).
  final List<int> rpmPoints;

  /// TPS % or load breakpoints for the column axis (one entry per column).
  final List<int> loadPoints;

  const AxisDescriptor({
    required this.rpmPoints,
    required this.loadPoints,
  });
}

/// Checksum algorithm location and parameters within the ROM.
class ChecksumDescriptor {
  /// First byte of the region that is checksummed (inclusive).
  final int startOffset;

  /// Last byte of the region that is checksummed (exclusive — like Dart ranges).
  final int endOffset;

  /// Offset within the ROM where the computed checksum value is stored.
  final int checksumOffset;

  /// Algorithm to use for compute/verify/correct.
  final ChecksumAlgorithm algorithm;

  const ChecksumDescriptor({
    required this.startOffset,
    required this.endOffset,
    required this.checksumOffset,
    required this.algorithm,
  });
}

/// Capability flags describing what operations are supported for this ECU.
class EcuCapabilities {
  /// Can read live OBD-II PIDs via standard Mode 01.
  final bool obdReading;

  /// Can read ECU identification (VIN, calibration ID, ECU part number).
  final bool ecuIdentification;

  /// Can read full ECU ROM binary (requires KWP2000 security access).
  final bool romRead;

  /// Can write ECU ROM binary (DANGER: irreversible without backup).
  final bool romWrite;

  /// Supports KWP2000 security seed/key exchange (needed for ROM read/write).
  final bool securityAccess;

  const EcuCapabilities({
    this.obdReading = true,
    this.ecuIdentification = false,
    this.romRead = false,
    this.romWrite = false,
    this.securityAccess = false,
  });

  /// Diagnostic-only capability set (ELM327 adapter, read OBD PIDs only).
  static const diagnosticOnly = EcuCapabilities(obdReading: true);

  /// Full research capability (OpenPort 2.0, documented protocol).
  static const fullResearch = EcuCapabilities(
    obdReading: true,
    ecuIdentification: true,
    romRead: true,
    romWrite: false,
    securityAccess: true,
  );

  /// Full read+write capability (requires OpenPort 2.0 + verified protocol).
  static const fullReadWrite = EcuCapabilities(
    obdReading: true,
    ecuIdentification: true,
    romRead: true,
    romWrite: true,
    securityAccess: true,
  );
}

/// Definition of a specific motorcycle ECU variant.
///
/// Ties an ECU chip to a list of compatible motorcycles, the protocols
/// it speaks, its ROM layout, and what the current software can do with it.
class EcuDefinition {
  /// Unique identifier used in the motorcycle model registry.
  final String id;

  /// Brand name of the ECU manufacturer.
  final String brand;

  /// Short human-readable name shown in the UI.
  final String displayName;

  /// ECU chip family.
  final EcuChipFamily chipFamily;

  /// OBD protocol used by this ECU.
  final OBDProtocol primaryProtocol;

  /// Fallback protocol to try if primary fails.
  final OBDProtocol? fallbackProtocol;

  /// KWP2000 target address header (used for addressed frames).
  final String? kwpTargetHeader;

  /// Whether this ECU's diagnostic port is standard 16-pin OBD-II.
  final bool hasStandardObdPort;

  /// Connector pin count if proprietary port.
  final int? proprietaryPinCount;

  /// What this ECU currently supports in the app.
  final EcuCapabilities capabilities;

  /// Motorcycle model IDs that use this ECU.
  final List<String> motorcycleModelIds;

  /// Human-readable note about flashing requirements or quirks.
  final String? notes;

  // ── Phase 2: KWP2000 protocol fields ──────────────────────────────────────

  /// KWP2000 ECU target byte address.
  /// Honda Keihin = 0x10 (engine ECU), Yamaha Shindengen = 0x11.
  final int kwpTargetAddress;

  /// Total ROM size in bytes. 65536 = 64KB (Click), 131072 = 128KB (Aerox).
  final int romSizeBytes;

  /// Security access seed→key algorithm for KWP2000 service 0x27.
  final SecurityAlgorithm securityAlgorithm;

  /// Known tunable maps within this ECU's ROM (fuel, ignition, VVA, etc.).
  final List<MapDescriptor> maps;

  /// Checksum specification for ROM integrity validation.
  final ChecksumDescriptor? checksumDescriptor;

  /// Default axis labels for fuel/ignition map display.
  final AxisDescriptor? defaultAxes;

  const EcuDefinition({
    required this.id,
    required this.brand,
    required this.displayName,
    required this.chipFamily,
    required this.primaryProtocol,
    this.fallbackProtocol,
    this.kwpTargetHeader,
    this.hasStandardObdPort = false,
    this.proprietaryPinCount,
    required this.capabilities,
    required this.motorcycleModelIds,
    this.notes,
    // Phase 2 fields — safe defaults preserve backward compat
    this.kwpTargetAddress = 0x00,
    this.romSizeBytes = 65536,
    this.securityAlgorithm = SecurityAlgorithm.none,
    this.maps = const [],
    this.checksumDescriptor,
    this.defaultAxes,
  });

  /// Returns the best protocol to use for a given adapter.
  OBDProtocol protocolForAdapter(AdapterInterface adapter) {
    if (!adapter.supportsKLineDirect) return OBDProtocol.auto;
    return primaryProtocol;
  }

  /// Look up a map descriptor by name (e.g. 'fuel_map', 'ignition_map').
  MapDescriptor? mapByName(String name) {
    for (final m in maps) {
      if (m.name == name) return m;
    }
    return null;
  }
}
