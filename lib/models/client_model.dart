class ClientModel {
  final String id; // UUID
  final String name;
  final String? phone;
  final String? plateNumber;
  final String? motorcycleBrand;
  final String? motorcycleModel;
  final String? motorcycleColor;
  final int? motorcycleYear;
  final int? currentOdometer;
  final DateTime createdAt;
  final DateTime? lastServiceAt;

  const ClientModel({
    required this.id,
    required this.name,
    this.phone,
    this.plateNumber,
    this.motorcycleBrand,
    this.motorcycleModel,
    this.motorcycleColor,
    this.motorcycleYear,
    this.currentOdometer,
    required this.createdAt,
    this.lastServiceAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'plateNumber': plateNumber,
      'motorcycleBrand': motorcycleBrand,
      'motorcycleModel': motorcycleModel,
      'motorcycleColor': motorcycleColor,
      'motorcycleYear': motorcycleYear,
      'currentOdometer': currentOdometer,
      'createdAt': createdAt.toIso8601String(),
      'lastServiceAt': lastServiceAt?.toIso8601String(),
    };
  }

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      plateNumber: map['plateNumber'] as String?,
      motorcycleBrand: map['motorcycleBrand'] as String?,
      motorcycleModel: map['motorcycleModel'] as String?,
      motorcycleColor: map['motorcycleColor'] as String?,
      motorcycleYear: map['motorcycleYear'] as int?,
      currentOdometer: map['currentOdometer'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastServiceAt: map['lastServiceAt'] != null
          ? DateTime.parse(map['lastServiceAt'] as String)
          : null,
    );
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? plateNumber,
    String? motorcycleBrand,
    String? motorcycleModel,
    String? motorcycleColor,
    int? motorcycleYear,
    int? currentOdometer,
    DateTime? createdAt,
    DateTime? lastServiceAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      plateNumber: plateNumber ?? this.plateNumber,
      motorcycleBrand: motorcycleBrand ?? this.motorcycleBrand,
      motorcycleModel: motorcycleModel ?? this.motorcycleModel,
      motorcycleColor: motorcycleColor ?? this.motorcycleColor,
      motorcycleYear: motorcycleYear ?? this.motorcycleYear,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      createdAt: createdAt ?? this.createdAt,
      lastServiceAt: lastServiceAt ?? this.lastServiceAt,
    );
  }
}
