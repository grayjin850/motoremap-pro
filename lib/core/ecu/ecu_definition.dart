import '../protocols/adapter_interface.dart';

/// Supported ECU chip families.
enum EcuChipFamily {
  shindengenRh850, // Yamaha Aerox 155, NMAX 155, MT-15 — Renesas RH850
  keihin,          // Honda CBR150R, CB150R, Click 125i — Keihin FI
  denso,           // Suzuki Raider R150 FI, GSX-S150 — Denso
  unknown,
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
    romWrite: false, // write enabled separately after research phase
    securityAccess: true,
  );
}

/// Definition of a specific motorcycle ECU variant.
///
/// Ties an ECU chip to a list of compatible motorcycles, the protocols
/// it speaks, and what the current software can do with it.
class EcuDefinition {
  /// Unique identifier used in the motorcycle model registry.
  final String id;

  /// Brand name of the ECU manufacturer.
  final String brand; // 'Shindengen', 'Keihin', 'Denso'

  /// Short human-readable name shown in the UI.
  final String displayName;

  /// ECU chip family.
  final EcuChipFamily chipFamily;

  /// OBD protocol used by this ECU.
  final OBDProtocol primaryProtocol;

  /// Fallback protocol to try if primary fails.
  final OBDProtocol? fallbackProtocol;

  /// KWP2000 target address header (used for addressed frames).
  /// Null for ECUs that use broadcast/auto-addressing.
  final String? kwpTargetHeader;

  /// Whether this ECU's diagnostic port is standard 16-pin OBD-II or
  /// a proprietary 3/4-pin connector requiring an adapter cable.
  final bool hasStandardObdPort;

  /// Connector pin count if proprietary port.
  final int? proprietaryPinCount;

  /// What this ECU currently supports in the app.
  final EcuCapabilities capabilities;

  /// Motorcycle model IDs that use this ECU.
  /// Matches the `id` field in the motorcycles DB table.
  final List<String> motorcycleModelIds;

  /// Human-readable note about flashing requirements or quirks.
  final String? notes;

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
  });

  /// Returns the best protocol to use for a given adapter.
  OBDProtocol protocolForAdapter(AdapterInterface adapter) {
    // If adapter doesn't support K-Line direct, default to auto (ELM327 handles it)
    if (!adapter.supportsKLineDirect) return OBDProtocol.auto;
    return primaryProtocol;
  }
}
