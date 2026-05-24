import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/motorcycle_model.dart';
import '../../models/tune_profile.dart';
import '../../models/session_log.dart';
import '../../models/client_model.dart';
import 'models_seed.dart';

/// Central SQLite helper for MotoRemap Pro.
/// All DB access goes through the singleton [database] getter.
class DbHelper {
  static const int _dbVersion = 1;
  static const String _dbName = 'motoremap.db';

  static Database? _database;

  DbHelper._();

  static Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------------------------
  // Schema creation
  // ---------------------------------------------------------------------------

  static Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await ModelsSeed.seedAll(db);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Stub — v1 → v2 migrations go here when needed
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE motorcycles (
        id TEXT PRIMARY KEY,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        year_from INTEGER NOT NULL,
        year_to INTEGER NOT NULL,
        variant TEXT NOT NULL,
        displacement INTEGER NOT NULL,
        compression_ratio REAL NOT NULL,
        bore REAL NOT NULL,
        stroke REAL NOT NULL,
        valve_system TEXT NOT NULL,
        valve_count INTEGER NOT NULL,
        has_vva INTEGER NOT NULL DEFAULT 0,
        vva_transition_rpm INTEGER NOT NULL DEFAULT 0,
        cooling TEXT NOT NULL,
        ecu_type TEXT NOT NULL,
        flash_tool TEXT NOT NULL,
        stock_rev_limit_soft INTEGER NOT NULL,
        stock_rev_limit_hard INTEGER NOT NULL,
        stock_speed_limit INTEGER NOT NULL,
        safe_afr_mid REAL NOT NULL,
        safe_afr_wot REAL NOT NULL,
        safe_afr_min REAL NOT NULL,
        safe_afr_max REAL NOT NULL,
        max_safe_rev_raise INTEGER NOT NULL,
        knock_rpm_zones TEXT NOT NULL DEFAULT '',
        expected_speed_by_level TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE tune_profiles (
        id TEXT PRIMARY KEY,
        motorcycle_model_id TEXT NOT NULL,
        type TEXT NOT NULL,
        name_taglish TEXT NOT NULL,
        description_taglish TEXT NOT NULL,
        afr_target_mid REAL NOT NULL,
        afr_target_wot REAL NOT NULL,
        timing_advance_deg INTEGER NOT NULL,
        rev_limit_raise INTEGER NOT NULL DEFAULT 0,
        remove_speed_limiter INTEGER NOT NULL DEFAULT 0,
        safety_score INTEGER NOT NULL,
        expected_benefits TEXT NOT NULL,
        fuel_consumption_note TEXT NOT NULL,
        fuel_map_json TEXT NOT NULL,
        ignition_map_json TEXT NOT NULL,
        FOREIGN KEY(motorcycle_model_id) REFERENCES motorcycles(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        motorcycle_model_id TEXT NOT NULL,
        motorcycle_brand TEXT NOT NULL,
        motorcycle_model TEXT NOT NULL,
        motorcycle_variant TEXT NOT NULL,
        motorcycle_year INTEGER NOT NULL,
        client_name TEXT,
        client_plate TEXT,
        profile_id TEXT,
        profile_name TEXT,
        pre_remap_safety_score INTEGER NOT NULL,
        tune_safety_score INTEGER,
        warnings_triggered TEXT NOT NULL DEFAULT '',
        obd_data_summary TEXT,
        technician_notes TEXT,
        result TEXT NOT NULL,
        requires_follow_up INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        plate_number TEXT,
        motorcycle_brand TEXT,
        motorcycle_model TEXT,
        motorcycle_color TEXT,
        motorcycle_year INTEGER,
        current_odometer INTEGER,
        created_at TEXT NOT NULL,
        last_service_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE safety_acknowledgments (
        id TEXT PRIMARY KEY,
        acknowledged_at TEXT NOT NULL,
        phrase_used TEXT NOT NULL,
        app_version TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE admin_changes (
        id TEXT PRIMARY KEY,
        changed_at TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        field_name TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // MotorcycleModel CRUD
  // ---------------------------------------------------------------------------

  /// Converts a [MotorcycleModel] to the snake_case column map used in the DB.
  static Map<String, dynamic> _motoToDbMap(MotorcycleModel m) => {
        'id': m.id,
        'brand': m.brand,
        'model': m.model,
        'year_from': m.yearFrom,
        'year_to': m.yearTo,
        'variant': m.variant,
        'displacement': m.displacement,
        'compression_ratio': m.compressionRatio,
        'bore': m.bore,
        'stroke': m.stroke,
        'valve_system': m.valveSystem,
        'valve_count': m.valveCount,
        'has_vva': m.hasVva ? 1 : 0,
        'vva_transition_rpm': m.vvaTransitionRpm,
        'cooling': m.cooling,
        'ecu_type': m.ecuType,
        'flash_tool': m.flashTool,
        'stock_rev_limit_soft': m.stockRevLimitSoft,
        'stock_rev_limit_hard': m.stockRevLimitHard,
        'stock_speed_limit': m.stockSpeedLimit,
        'safe_afr_mid': m.safeAfrMid,
        'safe_afr_wot': m.safeAfrWot,
        'safe_afr_min': m.safeAfrMin,
        'safe_afr_max': m.safeAfrMax,
        'max_safe_rev_raise': m.maxSafeRevRaise,
        'knock_rpm_zones': m.knockRpmZones.join(','),
        'expected_speed_by_level': m.expectedSpeedByLevel.entries
            .map((e) => '${e.key}:${e.value}')
            .join(','),
      };

  /// Converts a raw DB row (snake_case) back to [MotorcycleModel].
  static MotorcycleModel _motoFromDbRow(Map<String, dynamic> row) {
    final knockRaw = (row['knock_rpm_zones'] as String?) ?? '';
    final knockZones = knockRaw.isEmpty
        ? <int>[]
        : knockRaw.split(',').map(int.parse).toList();

    final speedRaw = (row['expected_speed_by_level'] as String?) ?? '';
    final speedMap = <int, double>{};
    if (speedRaw.isNotEmpty) {
      for (final entry in speedRaw.split(',')) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          speedMap[int.parse(parts[0])] = double.parse(parts[1]);
        }
      }
    }

    return MotorcycleModel(
      id: row['id'] as String,
      brand: row['brand'] as String,
      model: row['model'] as String,
      yearFrom: row['year_from'] as int,
      yearTo: row['year_to'] as int,
      variant: row['variant'] as String,
      displacement: row['displacement'] as int,
      compressionRatio: (row['compression_ratio'] as num).toDouble(),
      bore: (row['bore'] as num).toDouble(),
      stroke: (row['stroke'] as num).toDouble(),
      valveSystem: row['valve_system'] as String,
      valveCount: row['valve_count'] as int,
      hasVva: (row['has_vva'] as int) == 1,
      vvaTransitionRpm: row['vva_transition_rpm'] as int,
      cooling: row['cooling'] as String,
      ecuType: row['ecu_type'] as String,
      flashTool: row['flash_tool'] as String,
      stockRevLimitSoft: row['stock_rev_limit_soft'] as int,
      stockRevLimitHard: row['stock_rev_limit_hard'] as int,
      stockSpeedLimit: row['stock_speed_limit'] as int,
      safeAfrMid: (row['safe_afr_mid'] as num).toDouble(),
      safeAfrWot: (row['safe_afr_wot'] as num).toDouble(),
      safeAfrMin: (row['safe_afr_min'] as num).toDouble(),
      safeAfrMax: (row['safe_afr_max'] as num).toDouble(),
      maxSafeRevRaise: row['max_safe_rev_raise'] as int,
      knockRpmZones: knockZones,
      expectedSpeedByLevel: speedMap,
    );
  }

  static Future<void> insertMotorcycle(MotorcycleModel m) async {
    final db = await database;
    await db.insert(
      'motorcycles',
      _motoToDbMap(m),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<MotorcycleModel>> getAllMotorcycles() async {
    final db = await database;
    final rows = await db.query('motorcycles', orderBy: 'brand, model');
    return rows.map(_motoFromDbRow).toList();
  }

  static Future<MotorcycleModel?> getMotorcycleById(String id) async {
    final db = await database;
    final rows = await db.query(
      'motorcycles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _motoFromDbRow(rows.first);
  }

  /// Updates a motorcycle record and logs every changed field to [admin_changes].
  static Future<void> updateMotorcycle(MotorcycleModel updated) async {
    final db = await database;
    final existing = await getMotorcycleById(updated.id);
    if (existing == null) return;

    final oldMap = _motoToDbMap(existing);
    final newMap = _motoToDbMap(updated);
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'motorcycles',
        newMap,
        where: 'id = ?',
        whereArgs: [updated.id],
      );

      for (final key in newMap.keys) {
        final oldVal = oldMap[key]?.toString();
        final newVal = newMap[key]?.toString();
        if (oldVal != newVal) {
          await txn.insert('admin_changes', {
            'id': '${updated.id}_${key}_$now',
            'changed_at': now,
            'entity_type': 'motorcycle',
            'entity_id': updated.id,
            'field_name': key,
            'old_value': oldVal,
            'new_value': newVal,
          });
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // TuneProfile CRUD
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _profileToDbMap(TuneProfile p) => {
        'id': p.id,
        'motorcycle_model_id': p.motorcycleModelId,
        'type': p.type.name,
        'name_taglish': p.nameTaglish,
        'description_taglish': p.descriptionTaglish,
        'afr_target_mid': p.afrTargetMid,
        'afr_target_wot': p.afrTargetWot,
        'timing_advance_deg': p.timingAdvanceDeg,
        'rev_limit_raise': p.revLimitRaise,
        'remove_speed_limiter': p.removeSpeedLimiter ? 1 : 0,
        'safety_score': p.safetyScore,
        'expected_benefits': p.expectedBenefits,
        'fuel_consumption_note': p.fuelConsumptionNote,
        'fuel_map_json': p.fuelMapJson,
        'ignition_map_json': p.ignitionMapJson,
      };

  static TuneProfile _profileFromDbRow(Map<String, dynamic> row) {
    return TuneProfile(
      id: row['id'] as String,
      motorcycleModelId: row['motorcycle_model_id'] as String,
      type: ProfileType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => ProfileType.balanced,
      ),
      nameTaglish: row['name_taglish'] as String,
      descriptionTaglish: row['description_taglish'] as String,
      afrTargetMid: (row['afr_target_mid'] as num).toDouble(),
      afrTargetWot: (row['afr_target_wot'] as num).toDouble(),
      timingAdvanceDeg: row['timing_advance_deg'] as int,
      revLimitRaise: row['rev_limit_raise'] as int,
      removeSpeedLimiter: (row['remove_speed_limiter'] as int) == 1,
      safetyScore: row['safety_score'] as int,
      expectedBenefits: row['expected_benefits'] as String,
      fuelConsumptionNote: row['fuel_consumption_note'] as String,
      fuelMapJson: row['fuel_map_json'] as String,
      ignitionMapJson: row['ignition_map_json'] as String,
    );
  }

  static Future<void> insertProfile(TuneProfile profile) async {
    final db = await database;
    await db.insert(
      'tune_profiles',
      _profileToDbMap(profile),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<TuneProfile>> getProfilesByModelId(
      String motorcycleModelId) async {
    final db = await database;
    final rows = await db.query(
      'tune_profiles',
      where: 'motorcycle_model_id = ?',
      whereArgs: [motorcycleModelId],
      orderBy: 'safety_score DESC',
    );
    return rows.map(_profileFromDbRow).toList();
  }

  static Future<TuneProfile?> getProfileById(String id) async {
    final db = await database;
    final rows = await db.query(
      'tune_profiles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _profileFromDbRow(rows.first);
  }

  // ---------------------------------------------------------------------------
  // SessionLog — append-only
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _sessionToDbMap(SessionLog s) => {
        'id': s.id,
        'timestamp': s.timestamp.toIso8601String(),
        'motorcycle_model_id': s.motorcycleModelId,
        'motorcycle_brand': s.motorcycleBrand,
        'motorcycle_model': s.motorcycleModel,
        'motorcycle_variant': s.motorcycleVariant,
        'motorcycle_year': s.motorcycleYear,
        'client_name': s.clientName,
        'client_plate': s.clientPlate,
        'profile_id': s.profileId,
        'profile_name': s.profileName,
        'pre_remap_safety_score': s.preRemapSafetyScore,
        'tune_safety_score': s.tuneSafetyScore,
        'warnings_triggered': s.warningsTriggered.join('|'),
        'obd_data_summary': s.obdDataSummary,
        'technician_notes': s.technicianNotes,
        'result': s.result.name,
        'requires_follow_up': s.requiresFollowUp ? 1 : 0,
        'created_at':
            (s.createdAt ?? DateTime.now()).toIso8601String(),
      };

  static SessionLog _sessionFromDbRow(Map<String, dynamic> row) {
    final warnRaw = (row['warnings_triggered'] as String?) ?? '';
    final warnings =
        warnRaw.isEmpty ? <String>[] : warnRaw.split('|');

    return SessionLog(
      id: row['id'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      motorcycleModelId: row['motorcycle_model_id'] as String,
      motorcycleBrand: row['motorcycle_brand'] as String,
      motorcycleModel: row['motorcycle_model'] as String,
      motorcycleVariant: row['motorcycle_variant'] as String,
      motorcycleYear: row['motorcycle_year'] as int,
      clientName: row['client_name'] as String?,
      clientPlate: row['client_plate'] as String?,
      profileId: row['profile_id'] as String?,
      profileName: row['profile_name'] as String?,
      preRemapSafetyScore: row['pre_remap_safety_score'] as int,
      tuneSafetyScore: row['tune_safety_score'] as int?,
      warningsTriggered: warnings,
      obdDataSummary: row['obd_data_summary'] as String?,
      technicianNotes: row['technician_notes'] as String?,
      result: SessionResult.values.firstWhere(
        (e) => e.name == row['result'],
        orElse: () => SessionResult.success,
      ),
      requiresFollowUp: (row['requires_follow_up'] as int) == 1,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }

  /// Insert a new session — no update or delete methods exist by design.
  static Future<void> insertSession(SessionLog session) async {
    final db = await database;
    await db.insert(
      'sessions',
      _sessionToDbMap(session),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<List<SessionLog>> getAllSessions() async {
    final db = await database;
    final rows =
        await db.query('sessions', orderBy: 'timestamp DESC');
    return rows.map(_sessionFromDbRow).toList();
  }

  static Future<List<SessionLog>> getSessionsByModelId(
      String motorcycleModelId) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'motorcycle_model_id = ?',
      whereArgs: [motorcycleModelId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(_sessionFromDbRow).toList();
  }

  static Future<List<SessionLog>> getRecentSessions(int limit) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(_sessionFromDbRow).toList();
  }

  // ---------------------------------------------------------------------------
  // ClientModel CRUD
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _clientToDbMap(ClientModel c) => {
        'id': c.id,
        'name': c.name,
        'phone': c.phone,
        'plate_number': c.plateNumber,
        'motorcycle_brand': c.motorcycleBrand,
        'motorcycle_model': c.motorcycleModel,
        'motorcycle_color': c.motorcycleColor,
        'motorcycle_year': c.motorcycleYear,
        'current_odometer': c.currentOdometer,
        'created_at': c.createdAt.toIso8601String(),
        'last_service_at': c.lastServiceAt?.toIso8601String(),
      };

  static ClientModel _clientFromDbRow(Map<String, dynamic> row) {
    return ClientModel(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String?,
      plateNumber: row['plate_number'] as String?,
      motorcycleBrand: row['motorcycle_brand'] as String?,
      motorcycleModel: row['motorcycle_model'] as String?,
      motorcycleColor: row['motorcycle_color'] as String?,
      motorcycleYear: row['motorcycle_year'] as int?,
      currentOdometer: row['current_odometer'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String),
      lastServiceAt: row['last_service_at'] != null
          ? DateTime.parse(row['last_service_at'] as String)
          : null,
    );
  }

  static Future<void> insertClient(ClientModel client) async {
    final db = await database;
    await db.insert(
      'clients',
      _clientToDbMap(client),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ClientModel>> getAllClients() async {
    final db = await database;
    final rows =
        await db.query('clients', orderBy: 'name ASC');
    return rows.map(_clientFromDbRow).toList();
  }

  static Future<ClientModel?> getClientById(String id) async {
    final db = await database;
    final rows = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _clientFromDbRow(rows.first);
  }

  static Future<void> updateClient(ClientModel client) async {
    final db = await database;
    await db.update(
      'clients',
      _clientToDbMap(client),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  // ---------------------------------------------------------------------------
  // Safety Acknowledgments
  // ---------------------------------------------------------------------------

  static Future<void> insertAcknowledgment({
    required String id,
    required String phraseUsed,
    required String appVersion,
  }) async {
    final db = await database;
    await db.insert(
      'safety_acknowledgments',
      {
        'id': id,
        'acknowledged_at': DateTime.now().toIso8601String(),
        'phrase_used': phraseUsed,
        'app_version': appVersion,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getLastAcknowledgment() async {
    final db = await database;
    final rows = await db.query(
      'safety_acknowledgments',
      orderBy: 'acknowledged_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ---------------------------------------------------------------------------
  // AdminChange — internal audit log
  // ---------------------------------------------------------------------------

  static Future<void> insertAdminChange({
    required String id,
    required String entityType,
    required String entityId,
    required String fieldName,
    String? oldValue,
    String? newValue,
  }) async {
    final db = await database;
    await db.insert('admin_changes', {
      'id': id,
      'changed_at': DateTime.now().toIso8601String(),
      'entity_type': entityType,
      'entity_id': entityId,
      'field_name': fieldName,
      'old_value': oldValue,
      'new_value': newValue,
    });
  }

  // ---------------------------------------------------------------------------
  // Utility — close for testing
  // ---------------------------------------------------------------------------

  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
