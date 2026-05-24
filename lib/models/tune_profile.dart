import 'dart:convert';

// ---------------------------------------------------------------------------
// Engine feature flags — used for profile compatibility checks
// ---------------------------------------------------------------------------

enum EngineFeature {
  vva,              // Yamaha Variable Valve Actuation
  dohc,             // Dual overhead cam
  sohc,             // Single overhead cam
  fuelInjected,     // Electronic fuel injection
  liquidCooled,
  airCooled,
  displacement150Plus, // > 150cc
  displacement300Plus, // > 300cc
}

// ---------------------------------------------------------------------------
// Remap profile type taxonomy (16 types)
// ---------------------------------------------------------------------------

enum ProfileType {
  // Core performance
  topSpeed,           // Speed limiter delete + rev raise — highway
  balanced,           // All-around daily profile
  // City / commute
  cityResponse,       // Sharper throttle response for stop-and-go
  throttleSharpening, // Steep TPS-fuel slope for snappier feel
  throttleSmoothing,  // Gentle TPS-fuel slope for buttery city ride
  idleQuality,        // Idle RPM + mixture trim — fixes stalling
  // Fuel economy
  eco,                // Lean light-throttle map — max km/L
  // Specialty
  handling,           // Flat AFR across RPM — predictable cornering
  endurance,          // Highway long-haul — cool temps + stable fueling
  // Advanced
  vvaTransition,      // Smooths Yamaha VVA cam-switch zone (~6000 RPM)
  revLimiterRaise,    // Raises soft+hard rev limit only, no other changes
  decelFuelCut,       // Adjust DFCO threshold — removes decel pop/jerk
  coldStart,          // Warmup enrichment for cold Philippine mornings
  altitudeCompensation, // Leaner base map for Baguio/Benguet highlands
  exhaustTune,        // Richer mid-range after free-flow/cat-delete exhaust
  track,              // Aggressive timing + WOT AFR — track use only
}

// ---------------------------------------------------------------------------
// TuneProfile model
// ---------------------------------------------------------------------------

class TuneProfile {
  final String id;
  final String motorcycleModelId;
  final ProfileType type;
  final String nameTaglish;
  final String descriptionTaglish;
  final double afrTargetMid;
  final double afrTargetWot;
  final int timingAdvanceDeg;
  final int revLimitRaise;
  final bool removeSpeedLimiter;
  final int safetyScore;
  final String expectedBenefits;
  final String fuelConsumptionNote;
  final String fuelMapJson;
  final String ignitionMapJson;

  // Compatibility fields — new in v2
  final Set<EngineFeature> requiredFeatures; // empty = works on all bikes
  final Set<EngineFeature> incompatibleWith; // empty = no restrictions
  final int minDisplacementCc;               // 0 = no minimum
  final int maxDisplacementCc;               // 9999 = no maximum
  final String fuelRequirement;              // 'RON91', 'RON95', 'RON97'

  const TuneProfile({
    required this.id,
    required this.motorcycleModelId,
    required this.type,
    required this.nameTaglish,
    required this.descriptionTaglish,
    required this.afrTargetMid,
    required this.afrTargetWot,
    required this.timingAdvanceDeg,
    required this.revLimitRaise,
    required this.removeSpeedLimiter,
    required this.safetyScore,
    required this.expectedBenefits,
    required this.fuelConsumptionNote,
    required this.fuelMapJson,
    required this.ignitionMapJson,
    this.requiredFeatures = const {},
    this.incompatibleWith = const {},
    this.minDisplacementCc = 0,
    this.maxDisplacementCc = 9999,
    this.fuelRequirement = 'RON91',
  });

  List<List<double>> get fuelMap {
    final decoded = jsonDecode(fuelMapJson) as List<dynamic>;
    return decoded
        .map((row) => (row as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  List<List<double>> get ignitionMap {
    final decoded = jsonDecode(ignitionMapJson) as List<dynamic>;
    return decoded
        .map((row) => (row as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  static Set<EngineFeature> _parseFeatures(String raw) {
    if (raw.isEmpty) return const {};
    return raw
        .split(',')
        .map((s) => EngineFeature.values
            .where((e) => e.name == s.trim())
            .firstOrNull)
        .whereType<EngineFeature>()
        .toSet();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'motorcycleModelId': motorcycleModelId,
      'type': type.name,
      'nameTaglish': nameTaglish,
      'descriptionTaglish': descriptionTaglish,
      'afrTargetMid': afrTargetMid,
      'afrTargetWot': afrTargetWot,
      'timingAdvanceDeg': timingAdvanceDeg,
      'revLimitRaise': revLimitRaise,
      'removeSpeedLimiter': removeSpeedLimiter ? 1 : 0,
      'safetyScore': safetyScore,
      'expectedBenefits': expectedBenefits,
      'fuelConsumptionNote': fuelConsumptionNote,
      'fuelMapJson': fuelMapJson,
      'ignitionMapJson': ignitionMapJson,
      'required_features': requiredFeatures.map((e) => e.name).join(','),
      'incompatible_with': incompatibleWith.map((e) => e.name).join(','),
      'min_displacement': minDisplacementCc,
      'max_displacement': maxDisplacementCc,
      'fuel_requirement': fuelRequirement,
    };
  }

  factory TuneProfile.fromMap(Map<String, dynamic> map) {
    return TuneProfile(
      id: map['id'] as String,
      motorcycleModelId: map['motorcycleModelId'] as String? ??
          map['motorcycle_model_id'] as String,
      type: ProfileType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ProfileType.balanced,
      ),
      nameTaglish: map['nameTaglish'] as String? ??
          map['name_taglish'] as String,
      descriptionTaglish: map['descriptionTaglish'] as String? ??
          map['description_taglish'] as String,
      afrTargetMid: (map['afrTargetMid'] as num?)?.toDouble() ??
          (map['afr_target_mid'] as num).toDouble(),
      afrTargetWot: (map['afrTargetWot'] as num?)?.toDouble() ??
          (map['afr_target_wot'] as num).toDouble(),
      timingAdvanceDeg: map['timingAdvanceDeg'] as int? ??
          map['timing_advance_deg'] as int,
      revLimitRaise: map['revLimitRaise'] as int? ??
          map['rev_limit_raise'] as int? ?? 0,
      removeSpeedLimiter:
          ((map['removeSpeedLimiter'] ?? map['remove_speed_limiter']) as int? ?? 0) == 1,
      safetyScore: map['safetyScore'] as int? ??
          map['safety_score'] as int,
      expectedBenefits: map['expectedBenefits'] as String? ??
          map['expected_benefits'] as String,
      fuelConsumptionNote: map['fuelConsumptionNote'] as String? ??
          map['fuel_consumption_note'] as String,
      fuelMapJson: map['fuelMapJson'] as String? ??
          map['fuel_map_json'] as String,
      ignitionMapJson: map['ignitionMapJson'] as String? ??
          map['ignition_map_json'] as String,
      requiredFeatures: _parseFeatures(
          (map['required_features'] as String?) ?? ''),
      incompatibleWith: _parseFeatures(
          (map['incompatible_with'] as String?) ?? ''),
      minDisplacementCc: (map['min_displacement'] as int?) ?? 0,
      maxDisplacementCc: (map['max_displacement'] as int?) ?? 9999,
      fuelRequirement: (map['fuel_requirement'] as String?) ?? 'RON91',
    );
  }
}
