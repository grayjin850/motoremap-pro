import 'ecu_definition.dart';
import '../protocols/adapter_interface.dart';

/// Registry of all known motorcycle ECU definitions.
///
/// Entries are split into two tiers:
///   1. Generic entries — protocol + basic capabilities (OBD diagnostics)
///   2. Full-spec entries — complete ROM layout + map offsets + checksum
///      (required for actual read/flash operations in Phases 3–5)
class EcuRegistry {
  EcuRegistry._();

  // ──────────────────────────────────────────────────────────────────────────
  // TIER 1 — Generic ECU entries (OBD diagnostics tier)
  // ──────────────────────────────────────────────────────────────────────────

  static const EcuDefinition yamahaRh850 = EcuDefinition(
    id: 'shindengen_rh850_yamaha',
    brand: 'Shindengen',
    displayName: 'Shindengen RH850 (Yamaha VVA)',
    chipFamily: EcuChipFamily.shindengenRh850,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.auto,
    kwpTargetHeader: null,
    hasStandardObdPort: false,
    proprietaryPinCount: 4,
    capabilities: EcuCapabilities(
      obdReading: true,
      ecuIdentification: true,
      romRead: false,
      romWrite: false,
      securityAccess: false,
    ),
    motorcycleModelIds: [
      'yamaha_aerox155_vva_2017',
      'yamaha_nmax155_vva_2020',
      'yamaha_mt15_vva_2019',
    ],
    notes: 'Flash requires Backdoor Module + Renesas J-Link programmer. '
        'OBD reading via 4-pin diagnostic connector with adapter cable to ELM327.',
  );

  static const EcuDefinition yamahaShindR3 = EcuDefinition(
    id: 'shindengen_yamaha_r3',
    brand: 'Shindengen',
    displayName: 'Shindengen (Yamaha R3 321cc)',
    chipFamily: EcuChipFamily.shindengenRh850,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.auto,
    hasStandardObdPort: false,
    proprietaryPinCount: 4,
    capabilities: EcuCapabilities(obdReading: true, ecuIdentification: true),
    motorcycleModelIds: ['yamaha_r3_std_2019'],
    notes: 'Same family as RH850 but 321cc twin-cylinder variant. '
        'Flash via DiagBox + Renesas programmer.',
  );

  static const EcuDefinition hondaKeihin = EcuDefinition(
    id: 'keihin_honda_fi',
    brand: 'Keihin',
    displayName: 'Keihin FI (Honda CBR150R / CB150R / Click 125i)',
    chipFamily: EcuChipFamily.keihin,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.iso9141,
    hasStandardObdPort: false,
    proprietaryPinCount: 3,
    capabilities: EcuCapabilities(
      obdReading: true,
      ecuIdentification: true,
      romRead: false,
      romWrite: false,
      securityAccess: false,
    ),
    motorcycleModelIds: [
      'honda_cbr150r_std_2016',
      'honda_cb150r_std_2019',
      'honda_click125i_std_2021',
    ],
    notes: 'Honda 3-pin diagnostic port requires adapter to ELM327. '
        'Flash requires Honda HDS or HRC Flash Tool. '
        'KWP2000 seed/key documented for some Keihin variants.',
  );

  static const EcuDefinition suzukiDenso = EcuDefinition(
    id: 'denso_suzuki_fi',
    brand: 'Denso',
    displayName: 'Denso FI (Suzuki Raider R150 / GSX-S150 / Address 125)',
    chipFamily: EcuChipFamily.denso,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.iso9141,
    hasStandardObdPort: false,
    proprietaryPinCount: 6,
    capabilities: EcuCapabilities(
      obdReading: true,
      ecuIdentification: true,
      romRead: false,
      romWrite: false,
      securityAccess: false,
    ),
    motorcycleModelIds: [
      'suzuki_raider150fi_std_2018',
      'suzuki_gsxs150_std_2017',
      'suzuki_address125_std_2022',
    ],
    notes: 'Suzuki 6-pin diagnostic connector. '
        'Requires Suzuki SDS or compatible K-Line adapter. '
        'Denso ECU protocol partially documented in open-source community.',
  );

  // ──────────────────────────────────────────────────────────────────────────
  // TIER 2 — Full-spec entries with ROM layout (Phase 2+)
  // ──────────────────────────────────────────────────────────────────────────

  // ─── 2.7 Honda Click 125i ─────────────────────────────────────────────────
  //
  // ECU: Keihin PGM-FI 37820-KYZ (2014–2021 variant)
  // Protocol: KWP2000 fast-init / ISO 14230-4 / K-Line @ 10400 baud
  // ROM: 64KB, target address 0x10
  // Security: Keihin XOR seed→key
  //
  // Map offsets sourced from open-source PH tuning community documentation.
  // Verify against a known-good ROM dump before flashing.
  static const EcuDefinition hondaClick125i = EcuDefinition(
    id: 'keihin_click125i_pgmfi',
    brand: 'Keihin',
    displayName: 'Keihin PGM-FI (Honda Click 125i 2014–2021)',
    chipFamily: EcuChipFamily.keihin,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.iso9141,
    hasStandardObdPort: false,
    proprietaryPinCount: 3,
    capabilities: EcuCapabilities(
      obdReading: true,
      ecuIdentification: true,
      romRead: true,
      romWrite: true,
      securityAccess: true,
    ),
    motorcycleModelIds: ['honda_click125i_std_2021'],
    notes: 'Honda Click 125i 2014–2021. 3-pin Honda diagnostic connector. '
        'K-Line @ 10400 baud. OpenPort 2.0 required for ROM read/write. '
        'ECU part: 37820-KYZ. Map offsets community-researched — '
        'verify against known-good dump before first flash.',

    // KWP2000 parameters
    kwpTargetAddress: 0x10, // Honda engine ECU
    romSizeBytes: 65536,    // 64KB ROM
    securityAlgorithm: SecurityAlgorithm.keihinXor,

    // Map descriptors — offsets are approximate (±0x10 bytes depending on variant)
    maps: [
      MapDescriptor(
        name: 'fuel_map',
        romOffset: 0x4000,
        rows: 12,
        cols: 12,
        scale: 0.1,   // raw × 0.1 = kg/h
        offset: 0.0,
        unit: 'kg/h',
        safeMin: 0.5,
        safeMax: 15.0,
      ),
      MapDescriptor(
        name: 'ignition_map',
        romOffset: 0x5000,
        rows: 12,
        cols: 12,
        scale: 0.5,   // raw × 0.5 = degrees BTDC
        offset: 0.0,
        unit: 'deg BTDC',
        safeMin: 0.0,
        safeMax: 40.0,
      ),
    ],

    // Checksum: additive sum of all bytes 0x0000–0xFFFE, stored at 0xFFFF
    checksumDescriptor: ChecksumDescriptor(
      startOffset: 0x0000,
      endOffset: 0xFFFE,     // exclusive
      checksumOffset: 0xFFFF,
      algorithm: ChecksumAlgorithm.additiveByte,
    ),

    // 12-point RPM axis (idle to redline) and 12-point TPS% axis
    defaultAxes: AxisDescriptor(
      rpmPoints: [1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 6000, 7000, 8000],
      loadPoints: [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 100],
    ),
  );

  // ─── 2.8 Yamaha Aerox 155 / NMAX 155 ──────────────────────────────────────
  //
  // ECU: Shindengen RH850 (Aerox 155 VVA 2017+, NMAX 155 VVA 2020+)
  // Protocol: KWP2000 fast-init / ISO 14230-4 / K-Line @ 10400 baud
  // ROM: 128KB, target address 0x11
  // Security: Shindengen RH850 algorithm
  //
  // VVA (Variable Valve Actuation) transition at ~6000 RPM is safety-critical:
  // the VVA map must be smooth across the transition zone.
  static const EcuDefinition yamahaAerox155 = EcuDefinition(
    id: 'shindengen_aerox155_rh850',
    brand: 'Shindengen',
    displayName: 'Shindengen RH850 (Yamaha Aerox 155 / NMAX 155 VVA 2017+)',
    chipFamily: EcuChipFamily.shindengenRh850,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.auto,
    hasStandardObdPort: false,
    proprietaryPinCount: 4,
    capabilities: EcuCapabilities(
      obdReading: true,
      ecuIdentification: true,
      romRead: true,
      romWrite: true,
      securityAccess: true,
    ),
    motorcycleModelIds: [
      'yamaha_aerox155_vva_2017',
      'yamaha_nmax155_vva_2020',
    ],
    notes: 'Yamaha Aerox 155 VVA / NMAX 155 VVA. 4-pin Yamaha diagnostic. '
        'K-Line @ 10400 baud. 128KB ROM — requires chunked reads (128B/request). '
        'VVA cam switch at ~6000 RPM — VVA map MUST be smooth across this zone. '
        'OpenPort 2.0 required for ROM read/write.',

    // KWP2000 parameters
    kwpTargetAddress: 0x11, // Yamaha Shindengen ECU
    romSizeBytes: 131072,   // 128KB ROM
    securityAlgorithm: SecurityAlgorithm.shindengenRh850,

    // Map descriptors — offsets community-researched, verify before use
    maps: [
      MapDescriptor(
        name: 'fuel_injection',
        romOffset: 0x8000,
        rows: 16,
        cols: 16,
        scale: 0.1,   // raw × 0.1 = injection duration ms
        offset: 0.0,
        unit: 'ms',
        safeMin: 0.5,
        safeMax: 20.0,
      ),
      MapDescriptor(
        name: 'ignition_timing',
        romOffset: 0x9000,
        rows: 16,
        cols: 16,
        scale: 0.5,   // raw × 0.5 = degrees BTDC
        offset: 0.0,
        unit: 'deg BTDC',
        safeMin: -5.0,
        safeMax: 45.0,
      ),
      // VVA transition map: 0=low cam, 1=high cam
      // Critical: must be smooth across 5800–6200 RPM transition zone
      MapDescriptor(
        name: 'vva_transition',
        romOffset: 0xA000,
        rows: 8,
        cols: 16,
        scale: 1.0,
        offset: 0.0,
        unit: 'binary',
        safeMin: 0.0,
        safeMax: 1.0,
      ),
    ],

    // Checksum: CRC16 of the first 128KB block region
    // Multiple checksum blocks exist — this covers the primary region
    checksumDescriptor: ChecksumDescriptor(
      startOffset: 0x0000,
      endOffset: 0x1FFFE,     // exclusive — first 128KB region
      checksumOffset: 0x1FFFF, // CRC stored at end of primary block
      algorithm: ChecksumAlgorithm.crc16,
    ),

    // 16-point axes covering idle through high-RPM + VVA transition zone
    defaultAxes: AxisDescriptor(
      rpmPoints: [
        1000, 1500, 2000, 2500, 3000, 3500,
        4000, 4500, 5000, 5500, 6000, 6500,
        7000, 7500, 8000, 9000,
      ],
      loadPoints: [0, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 95, 97, 99, 100],
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Registry
  // ──────────────────────────────────────────────────────────────────────────

  static const List<EcuDefinition> _all = [
    // Tier 1 — generic
    yamahaRh850,
    yamahaShindR3,
    hondaKeihin,
    suzukiDenso,
    // Tier 2 — full-spec with ROM layout
    hondaClick125i,
    yamahaAerox155,
  ];

  static List<EcuDefinition> get all => _all;

  /// Find all ECUs that support full read/write operations.
  static List<EcuDefinition> get flashCapable =>
      _all.where((e) => e.capabilities.romWrite).toList();

  /// Find the ECU definition for a given motorcycle model ID.
  ///
  /// Returns the most capable (highest tier) definition if multiple match.
  static EcuDefinition? forMotorcycleModel(String motorcycleModelId) {
    // Search tier 2 first (more specific)
    for (final ecu in _all.reversed) {
      if (ecu.motorcycleModelIds.contains(motorcycleModelId)) return ecu;
    }
    return null;
  }

  /// Find ECU by its registry ID.
  static EcuDefinition? byId(String id) {
    try {
      return _all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
