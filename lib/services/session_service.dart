import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/database/db_helper.dart';
import '../models/session_log.dart';

// ---------------------------------------------------------------------------
// SessionService
// ---------------------------------------------------------------------------

/// Service for creating and querying session logs.
///
/// Session logs are APPEND-ONLY — there are no update or delete methods here
/// (by design, matching the DB constraint: ConflictAlgorithm.ignore on insert).
/// To record a changed outcome, create a new [SessionLog] with updated fields.
class SessionService {
  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Write — append-only
  // ---------------------------------------------------------------------------

  /// Create and persist a new session log, returning the stored [SessionLog].
  ///
  /// [result] defaults to [SessionResult.success]; call [recordCompletion]
  /// to create a completion record once the remap session is finished.
  Future<SessionLog> startSession({
    required String motorcycleModelId,
    required String motorcycleBrand,
    required String motorcycleModel,
    required String motorcycleVariant,
    required int motorcycleYear,
    String? clientName,
    String? clientPlate,
    String? profileId,
    String? profileName,
    required int preRemapSafetyScore,
    List<String> warningsTriggered = const [],
    String? obdDataSummary,
    String? technicianNotes,
    bool requiresFollowUp = false,
  }) async {
    final now = DateTime.now();
    final session = SessionLog(
      id: _uuid.v4(),
      timestamp: now,
      motorcycleModelId: motorcycleModelId,
      motorcycleBrand: motorcycleBrand,
      motorcycleModel: motorcycleModel,
      motorcycleVariant: motorcycleVariant,
      motorcycleYear: motorcycleYear,
      clientName: clientName,
      clientPlate: clientPlate,
      profileId: profileId,
      profileName: profileName,
      preRemapSafetyScore: preRemapSafetyScore,
      tuneSafetyScore: null,
      warningsTriggered: warningsTriggered,
      obdDataSummary: obdDataSummary,
      technicianNotes: technicianNotes,
      result: SessionResult.success,
      requiresFollowUp: requiresFollowUp,
      createdAt: now,
    );
    await DbHelper.insertSession(session);
    return session;
  }

  /// Record the completion of a session by appending a new [SessionLog] entry
  /// with the final [result], [tuneSafetyScore], notes, and any OBD summary.
  ///
  /// Because session logs are append-only, this creates a second record
  /// with the same [motorcycleModelId] but a distinct UUID and the completed
  /// state. The original start record is preserved in full.
  Future<SessionLog> recordCompletion({
    required String motorcycleModelId,
    required String motorcycleBrand,
    required String motorcycleModel,
    required String motorcycleVariant,
    required int motorcycleYear,
    String? clientName,
    String? clientPlate,
    String? profileId,
    String? profileName,
    required int preRemapSafetyScore,
    int? tuneSafetyScore,
    List<String> warningsTriggered = const [],
    String? obdDataSummary,
    String? technicianNotes,
    required SessionResult result,
    bool requiresFollowUp = false,
  }) async {
    final now = DateTime.now();
    final session = SessionLog(
      id: _uuid.v4(),
      timestamp: now,
      motorcycleModelId: motorcycleModelId,
      motorcycleBrand: motorcycleBrand,
      motorcycleModel: motorcycleModel,
      motorcycleVariant: motorcycleVariant,
      motorcycleYear: motorcycleYear,
      clientName: clientName,
      clientPlate: clientPlate,
      profileId: profileId,
      profileName: profileName,
      preRemapSafetyScore: preRemapSafetyScore,
      tuneSafetyScore: tuneSafetyScore,
      warningsTriggered: warningsTriggered,
      obdDataSummary: obdDataSummary,
      technicianNotes: technicianNotes,
      result: result,
      requiresFollowUp: requiresFollowUp,
      createdAt: now,
    );
    await DbHelper.insertSession(session);
    return session;
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Return the [limit] most-recent sessions, ordered newest-first.
  Future<List<SessionLog>> getRecentSessions({int limit = 5}) async {
    return DbHelper.getRecentSessions(limit);
  }

  /// Return all sessions, ordered newest-first.
  Future<List<SessionLog>> getAllSessions() async {
    return DbHelper.getAllSessions();
  }

  /// Return all sessions for a specific motorcycle model.
  Future<List<SessionLog>> getSessionsByModel(String motorcycleModelId) async {
    return DbHelper.getSessionsByModelId(motorcycleModelId);
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final sessionServiceProvider = Provider<SessionService>((ref) => SessionService());
