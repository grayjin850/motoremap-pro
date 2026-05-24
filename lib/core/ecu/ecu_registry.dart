import 'ecu_definition.dart';
import '../protocols/adapter_interface.dart';

/// Registry of all known motorcycle ECU definitions.
///
/// Each entry documents the protocol, connector type, and current
/// software capability level for that ECU variant.
class EcuRegistry {
  EcuRegistry._();

  // ---------------------------------------------------------------------------
  // Shindengen RH850 (Yamaha VVA bikes)
  // ---------------------------------------------------------------------------
  static const EcuDefinition yamahaRh850 = EcuDefinition(
    id: 'shindengen_rh850_yamaha',
    brand: 'Shindengen',
    displayName: 'Shindengen RH850 (Yamaha VVA)',
    chipFamily: EcuChipFamily.shindengenRh850,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.auto,
    kwpTargetHeader: null, // auto-addressed
    hasStandardObdPort: false,
    proprietaryPinCount: 4, // Yamaha 4-pin diagnostic connector
    capabilities: EcuCapabilities(
      obdReading: true,
      ecuIdentification: true, // Mode 09 supported
      romRead: false,          // requires Backdoor Module — Phase 2
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

  // ---------------------------------------------------------------------------
  // Shindengen (Yamaha R3, non-VVA)
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Keihin (Honda FI bikes)
  // ---------------------------------------------------------------------------
  static const EcuDefinition hondaKeihin = EcuDefinition(
    id: 'keihin_honda_fi',
    brand: 'Keihin',
    displayName: 'Keihin FI (Honda CBR150R / CB150R / Click 125i)',
    chipFamily: EcuChipFamily.keihin,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.iso9141,
    hasStandardObdPort: false,
    proprietaryPinCount: 3, // Honda 3-pin diagnostic connector (older models)
    capabilities: EcuCapabilities(
      obdReading: true,
      ecuIdentification: true,
      romRead: false,   // Phase 2 — HDS protocol research required
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

  // ---------------------------------------------------------------------------
  // Denso (Suzuki FI bikes)
  // ---------------------------------------------------------------------------
  static const EcuDefinition suzukiDenso = EcuDefinition(
    id: 'denso_suzuki_fi',
    brand: 'Denso',
    displayName: 'Denso FI (Suzuki Raider R150 / GSX-S150 / Address 125)',
    chipFamily: EcuChipFamily.denso,
    primaryProtocol: OBDProtocol.kwp2000Fast,
    fallbackProtocol: OBDProtocol.iso9141,
    hasStandardObdPort: false,
    proprietaryPinCount: 6, // Suzuki 6-pin connector
    capabilities: EcuCapabilities(
      obdReading: true,
      ecuIdentification: true,
      romRead: false,   // Phase 2 — Denso protocol research
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

  // ---------------------------------------------------------------------------
  // Registry lookup methods
  // ---------------------------------------------------------------------------

  static const List<EcuDefinition> _all = [
    yamahaRh850,
    yamahaShindR3,
    hondaKeihin,
    suzukiDenso,
  ];

  static List<EcuDefinition> get all => _all;

  /// Find the ECU definition for a given motorcycle model ID.
  static EcuDefinition? forMotorcycleModel(String motorcycleModelId) {
    for (final ecu in _all) {
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
