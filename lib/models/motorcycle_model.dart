class MotorcycleModel {
  final String id;
  final String brand;
  final String model;
  final int yearFrom;
  final int yearTo; // 0 means present
  final String variant;
  final int displacement; // cc
  final double compressionRatio;
  final double bore; // mm
  final double stroke; // mm
  final String valveSystem; // 'SOHC', 'DOHC'
  final int valveCount;
  final bool hasVva;
  final int vvaTransitionRpm; // 0 if no VVA
  final String cooling; // 'air', 'liquid'
  final String ecuType;
  final String flashTool;
  final int stockRevLimitSoft; // RPM
  final int stockRevLimitHard; // RPM
  final int stockSpeedLimit; // km/h
  final double safeAfrMid;
  final double safeAfrWot;
  final double safeAfrMin;
  final double safeAfrMax;
  final int maxSafeRevRaise; // max RPM (absolute)
  final List<int> knockRpmZones;
  final Map<int, double> expectedSpeedByLevel;

  const MotorcycleModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.yearFrom,
    required this.yearTo,
    required this.variant,
    required this.displacement,
    required this.compressionRatio,
    required this.bore,
    required this.stroke,
    required this.valveSystem,
    required this.valveCount,
    required this.hasVva,
    required this.vvaTransitionRpm,
    required this.cooling,
    required this.ecuType,
    required this.flashTool,
    required this.stockRevLimitSoft,
    required this.stockRevLimitHard,
    required this.stockSpeedLimit,
    required this.safeAfrMid,
    required this.safeAfrWot,
    required this.safeAfrMin,
    required this.safeAfrMax,
    required this.maxSafeRevRaise,
    required this.knockRpmZones,
    required this.expectedSpeedByLevel,
  });

  /// Compute max timing advance from compression ratio.
  /// >= 11.5:1 -> max +3 deg, 11.0-11.5:1 -> max +4 deg, < 11.0:1 -> max +5 deg
  int get maxTimingAdvance {
    if (compressionRatio >= 11.5) return 3;
    if (compressionRatio >= 11.0) return 4;
    return 5;
  }

  /// Check if this model has VVA in the given RPM range (+/- 200 rpm of transition point).
  bool isInVvaZone(int rpm) {
    if (!hasVva) return false;
    return rpm >= (vvaTransitionRpm - 200) && rpm <= (vvaTransitionRpm + 200);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'yearFrom': yearFrom,
      'yearTo': yearTo,
      'variant': variant,
      'displacement': displacement,
      'compressionRatio': compressionRatio,
      'bore': bore,
      'stroke': stroke,
      'valveSystem': valveSystem,
      'valveCount': valveCount,
      'hasVva': hasVva ? 1 : 0,
      'vvaTransitionRpm': vvaTransitionRpm,
      'cooling': cooling,
      'ecuType': ecuType,
      'flashTool': flashTool,
      'stockRevLimitSoft': stockRevLimitSoft,
      'stockRevLimitHard': stockRevLimitHard,
      'stockSpeedLimit': stockSpeedLimit,
      'safeAfrMid': safeAfrMid,
      'safeAfrWot': safeAfrWot,
      'safeAfrMin': safeAfrMin,
      'safeAfrMax': safeAfrMax,
      'maxSafeRevRaise': maxSafeRevRaise,
      'knockRpmZones': knockRpmZones.join(','),
      'expectedSpeedByLevel': expectedSpeedByLevel.entries
          .map((e) => '${e.key}:${e.value}')
          .join(','),
    };
  }

  factory MotorcycleModel.fromMap(Map<String, dynamic> map) {
    final knockRpmRaw = (map['knockRpmZones'] as String?) ?? '';
    final List<int> knockRpmZones = knockRpmRaw.isEmpty
        ? []
        : knockRpmRaw.split(',').map(int.parse).toList();

    final speedRaw = (map['expectedSpeedByLevel'] as String?) ?? '';
    final Map<int, double> expectedSpeedByLevel = {};
    if (speedRaw.isNotEmpty) {
      for (final entry in speedRaw.split(',')) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          expectedSpeedByLevel[int.parse(parts[0])] =
              double.parse(parts[1]);
        }
      }
    }

    return MotorcycleModel(
      id: map['id'] as String,
      brand: map['brand'] as String,
      model: map['model'] as String,
      yearFrom: map['yearFrom'] as int,
      yearTo: map['yearTo'] as int,
      variant: map['variant'] as String,
      displacement: map['displacement'] as int,
      compressionRatio: (map['compressionRatio'] as num).toDouble(),
      bore: (map['bore'] as num).toDouble(),
      stroke: (map['stroke'] as num).toDouble(),
      valveSystem: map['valveSystem'] as String,
      valveCount: map['valveCount'] as int,
      hasVva: (map['hasVva'] as int) == 1,
      vvaTransitionRpm: map['vvaTransitionRpm'] as int,
      cooling: map['cooling'] as String,
      ecuType: map['ecuType'] as String,
      flashTool: map['flashTool'] as String,
      stockRevLimitSoft: map['stockRevLimitSoft'] as int,
      stockRevLimitHard: map['stockRevLimitHard'] as int,
      stockSpeedLimit: map['stockSpeedLimit'] as int,
      safeAfrMid: (map['safeAfrMid'] as num).toDouble(),
      safeAfrWot: (map['safeAfrWot'] as num).toDouble(),
      safeAfrMin: (map['safeAfrMin'] as num).toDouble(),
      safeAfrMax: (map['safeAfrMax'] as num).toDouble(),
      maxSafeRevRaise: map['maxSafeRevRaise'] as int,
      knockRpmZones: knockRpmZones,
      expectedSpeedByLevel: expectedSpeedByLevel,
    );
  }

  MotorcycleModel copyWith({
    String? id,
    String? brand,
    String? model,
    int? yearFrom,
    int? yearTo,
    String? variant,
    int? displacement,
    double? compressionRatio,
    double? bore,
    double? stroke,
    String? valveSystem,
    int? valveCount,
    bool? hasVva,
    int? vvaTransitionRpm,
    String? cooling,
    String? ecuType,
    String? flashTool,
    int? stockRevLimitSoft,
    int? stockRevLimitHard,
    int? stockSpeedLimit,
    double? safeAfrMid,
    double? safeAfrWot,
    double? safeAfrMin,
    double? safeAfrMax,
    int? maxSafeRevRaise,
    List<int>? knockRpmZones,
    Map<int, double>? expectedSpeedByLevel,
  }) {
    return MotorcycleModel(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      yearFrom: yearFrom ?? this.yearFrom,
      yearTo: yearTo ?? this.yearTo,
      variant: variant ?? this.variant,
      displacement: displacement ?? this.displacement,
      compressionRatio: compressionRatio ?? this.compressionRatio,
      bore: bore ?? this.bore,
      stroke: stroke ?? this.stroke,
      valveSystem: valveSystem ?? this.valveSystem,
      valveCount: valveCount ?? this.valveCount,
      hasVva: hasVva ?? this.hasVva,
      vvaTransitionRpm: vvaTransitionRpm ?? this.vvaTransitionRpm,
      cooling: cooling ?? this.cooling,
      ecuType: ecuType ?? this.ecuType,
      flashTool: flashTool ?? this.flashTool,
      stockRevLimitSoft: stockRevLimitSoft ?? this.stockRevLimitSoft,
      stockRevLimitHard: stockRevLimitHard ?? this.stockRevLimitHard,
      stockSpeedLimit: stockSpeedLimit ?? this.stockSpeedLimit,
      safeAfrMid: safeAfrMid ?? this.safeAfrMid,
      safeAfrWot: safeAfrWot ?? this.safeAfrWot,
      safeAfrMin: safeAfrMin ?? this.safeAfrMin,
      safeAfrMax: safeAfrMax ?? this.safeAfrMax,
      maxSafeRevRaise: maxSafeRevRaise ?? this.maxSafeRevRaise,
      knockRpmZones: knockRpmZones ?? this.knockRpmZones,
      expectedSpeedByLevel: expectedSpeedByLevel ?? this.expectedSpeedByLevel,
    );
  }
}
