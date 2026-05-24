import 'dart:convert';

enum ProfileType { topSpeed, cityResponse, handling, balanced, eco }

class TuneProfile {
  final String id;
  final String motorcycleModelId;
  final ProfileType type;
  final String nameTaglish;
  final String descriptionTaglish;
  final double afrTargetMid;
  final double afrTargetWot;
  final int timingAdvanceDeg;
  final int revLimitRaise; // RPM to add to stock limit (0 = no change)
  final bool removeSpeedLimiter;
  final int safetyScore; // pre-computed 0-100
  final String expectedBenefits;
  final String fuelConsumptionNote;
  /// 12x12 target AFR map stored as JSON string (List<List<double>>)
  final String fuelMapJson;
  /// 12x12 target ignition map stored as JSON string (List<List<double>>)
  final String ignitionMapJson;

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
  });

  /// Deserialize the 12x12 fuel AFR map from JSON.
  List<List<double>> get fuelMap {
    final decoded = jsonDecode(fuelMapJson) as List<dynamic>;
    return decoded
        .map((row) => (row as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  /// Deserialize the 12x12 ignition advance map from JSON.
  List<List<double>> get ignitionMap {
    final decoded = jsonDecode(ignitionMapJson) as List<dynamic>;
    return decoded
        .map((row) => (row as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();
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
    };
  }

  factory TuneProfile.fromMap(Map<String, dynamic> map) {
    return TuneProfile(
      id: map['id'] as String,
      motorcycleModelId: map['motorcycleModelId'] as String,
      type: ProfileType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ProfileType.balanced,
      ),
      nameTaglish: map['nameTaglish'] as String,
      descriptionTaglish: map['descriptionTaglish'] as String,
      afrTargetMid: (map['afrTargetMid'] as num).toDouble(),
      afrTargetWot: (map['afrTargetWot'] as num).toDouble(),
      timingAdvanceDeg: map['timingAdvanceDeg'] as int,
      revLimitRaise: map['revLimitRaise'] as int,
      removeSpeedLimiter: (map['removeSpeedLimiter'] as int) == 1,
      safetyScore: map['safetyScore'] as int,
      expectedBenefits: map['expectedBenefits'] as String,
      fuelConsumptionNote: map['fuelConsumptionNote'] as String,
      fuelMapJson: map['fuelMapJson'] as String,
      ignitionMapJson: map['ignitionMapJson'] as String,
    );
  }
}
