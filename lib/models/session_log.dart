enum SessionResult { success, issues, rollbackNeeded }

/// Append-only session log. No update methods — only factory constructor + toMap().
class SessionLog {
  final String id; // UUID
  final DateTime timestamp;
  final String motorcycleModelId;
  final String motorcycleBrand;
  final String motorcycleModel;
  final String motorcycleVariant;
  final int motorcycleYear;
  final String? clientName;
  final String? clientPlate;
  final String? profileId;
  final String? profileName;
  final int preRemapSafetyScore;
  final int? tuneSafetyScore;
  final List<String> warningsTriggered;
  final String? obdDataSummary; // JSON summary
  final String? technicianNotes;
  final SessionResult result;
  final bool requiresFollowUp;
  final DateTime? createdAt;

  const SessionLog({
    required this.id,
    required this.timestamp,
    required this.motorcycleModelId,
    required this.motorcycleBrand,
    required this.motorcycleModel,
    required this.motorcycleVariant,
    required this.motorcycleYear,
    this.clientName,
    this.clientPlate,
    this.profileId,
    this.profileName,
    required this.preRemapSafetyScore,
    this.tuneSafetyScore,
    required this.warningsTriggered,
    this.obdDataSummary,
    this.technicianNotes,
    required this.result,
    required this.requiresFollowUp,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'motorcycleModelId': motorcycleModelId,
      'motorcycleBrand': motorcycleBrand,
      'motorcycleModel': motorcycleModel,
      'motorcycleVariant': motorcycleVariant,
      'motorcycleYear': motorcycleYear,
      'clientName': clientName,
      'clientPlate': clientPlate,
      'profileId': profileId,
      'profileName': profileName,
      'preRemapSafetyScore': preRemapSafetyScore,
      'tuneSafetyScore': tuneSafetyScore,
      'warningsTriggered': warningsTriggered.join('|'),
      'obdDataSummary': obdDataSummary,
      'technicianNotes': technicianNotes,
      'result': result.name,
      'requiresFollowUp': requiresFollowUp ? 1 : 0,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory SessionLog.fromMap(Map<String, dynamic> map) {
    final warningsRaw = (map['warningsTriggered'] as String?) ?? '';
    final List<String> warningsTriggered = warningsRaw.isEmpty
        ? []
        : warningsRaw.split('|');

    return SessionLog(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      motorcycleModelId: map['motorcycleModelId'] as String,
      motorcycleBrand: map['motorcycleBrand'] as String,
      motorcycleModel: map['motorcycleModel'] as String,
      motorcycleVariant: map['motorcycleVariant'] as String,
      motorcycleYear: map['motorcycleYear'] as int,
      clientName: map['clientName'] as String?,
      clientPlate: map['clientPlate'] as String?,
      profileId: map['profileId'] as String?,
      profileName: map['profileName'] as String?,
      preRemapSafetyScore: map['preRemapSafetyScore'] as int,
      tuneSafetyScore: map['tuneSafetyScore'] as int?,
      warningsTriggered: warningsTriggered,
      obdDataSummary: map['obdDataSummary'] as String?,
      technicianNotes: map['technicianNotes'] as String?,
      result: SessionResult.values.firstWhere(
        (e) => e.name == map['result'],
        orElse: () => SessionResult.success,
      ),
      requiresFollowUp: (map['requiresFollowUp'] as int) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
    );
  }
}
