import 'dart:async';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// ── Frame direction ───────────────────────────────────────────────────────────

enum FrameDirection { tx, rx }

// ── Log entry ─────────────────────────────────────────────────────────────────

class KwpFrameEntry {
  final int id;
  final DateTime timestamp;
  final FrameDirection direction;
  final int serviceId;
  final String dataHex;
  final String? nrcCode;    // populated on negative response (0x7F)
  final String description; // human-readable service name

  const KwpFrameEntry({
    required this.id,
    required this.timestamp,
    required this.direction,
    required this.serviceId,
    required this.dataHex,
    required this.description,
    this.nrcCode,
  });

  String get directionLabel => direction == FrameDirection.tx ? 'TX' : 'RX';

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get oneLineSummary =>
      '[$formattedTime] $directionLabel  '
      '${serviceId.toRadixString(16).toUpperCase().padLeft(2, '0')}  '
      '${nrcCode != null ? "[NRC $nrcCode] " : ""}'
      '$description  |  $dataHex';
}

// ── Logger ────────────────────────────────────────────────────────────────────

/// Persistent KWP2000 protocol logger.
///
/// Records every frame sent to and received from the ECU with a high-resolution
/// timestamp, service ID, full hex payload, and NRC code if the response is
/// negative. Data is stored in SQLite and can be exported as a plain-text log
/// for hardware debugging.
///
/// Lifecycle:
///   1. Call [startSession(ecuId)] before opening a KWP session.
///   2. Call [logTx] / [logRx] for each frame.
///   3. Call [endSession()] when the session closes.
///   4. Call [exportSessionText(sessionId)] to get the log as a string.
class KwpProtocolLogger {
  static const String _dbName = 'kwp_log.db';
  static const String _tableName = 'kwp_frames';
  static const String _sessionsTable = 'kwp_sessions';

  KwpProtocolLogger._();
  static final KwpProtocolLogger instance = KwpProtocolLogger._();

  Database? _db;
  int? _activeSessionId;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> _open() async {
    if (_db != null) return;
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE $_sessionsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ecu_id TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            direction TEXT NOT NULL,
            service_id INTEGER NOT NULL,
            data_hex TEXT NOT NULL,
            nrc_code TEXT,
            description TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Begin a new logging session for [ecuId]. Returns the session ID.
  Future<int> startSession(String ecuId) async {
    await _open();
    _activeSessionId = await _db!.insert(_sessionsTable, {
      'ecu_id': ecuId,
      'started_at': DateTime.now().millisecondsSinceEpoch,
    });
    return _activeSessionId!;
  }

  /// Close the active session.
  Future<void> endSession() async {
    if (_activeSessionId == null || _db == null) return;
    await _db!.update(
      _sessionsTable,
      {'ended_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [_activeSessionId],
    );
    _activeSessionId = null;
  }

  // ── Logging ───────────────────────────────────────────────────────────────

  /// Log a frame transmitted TO the ECU.
  Future<void> logTx(Uint8List frame) async {
    await _log(FrameDirection.tx, frame);
  }

  /// Log a frame received FROM the ECU.
  Future<void> logRx(Uint8List frame) async {
    await _log(FrameDirection.rx, frame);
  }

  Future<void> _log(FrameDirection dir, Uint8List frame) async {
    if (_db == null || _activeSessionId == null) return;
    final serviceId = _extractServiceId(dir, frame);
    final nrc = _extractNrc(frame);
    await _db!.insert(_tableName, {
      'session_id': _activeSessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'direction': dir == FrameDirection.tx ? 'TX' : 'RX',
      'service_id': serviceId,
      'data_hex': _toHex(frame),
      'nrc_code': nrc,
      'description': _describeService(serviceId, dir, nrc),
    });
  }

  // ── Query / Export ────────────────────────────────────────────────────────

  /// Returns all frames for a specific [sessionId] in chronological order.
  Future<List<KwpFrameEntry>> framesForSession(int sessionId) async {
    await _open();
    final rows = await _db!.query(
      _tableName,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_rowToEntry).toList();
  }

  /// Returns all frames for the currently active session.
  Future<List<KwpFrameEntry>> currentSessionFrames() async {
    if (_activeSessionId == null) return [];
    return framesForSession(_activeSessionId!);
  }

  /// Export [sessionId] as a human-readable plain-text log string.
  Future<String> exportSessionText(int sessionId) async {
    final frames = await framesForSession(sessionId);
    if (frames.isEmpty) return '(no frames logged)';
    final buf = StringBuffer();
    buf.writeln('KWP2000 Protocol Log — Session $sessionId');
    buf.writeln('Generated: ${DateTime.now()}');
    buf.writeln('Frame count: ${frames.length}');
    buf.writeln('=' * 72);
    for (final f in frames) {
      buf.writeln(f.oneLineSummary);
    }
    return buf.toString();
  }

  /// Delete all frames and sessions older than [keepDays] days.
  Future<void> pruneOlderThan(int keepDays) async {
    await _open();
    final cutoff = DateTime.now()
        .subtract(Duration(days: keepDays))
        .millisecondsSinceEpoch;
    final old = await _db!.query(
      _sessionsTable,
      columns: ['id'],
      where: 'started_at < ?',
      whereArgs: [cutoff],
    );
    for (final row in old) {
      final id = row['id'] as int;
      await _db!.delete(_tableName, where: 'session_id = ?', whereArgs: [id]);
      await _db!.delete(_sessionsTable, where: 'id = ?', whereArgs: [id]);
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static int _extractServiceId(FrameDirection dir, Uint8List frame) {
    // KWP2000 addressed frame: [0x80|len, tgt, src, len, serviceId, ...]
    // Minimal frame detection: look for service ID at byte index 4
    if (frame.length >= 5) return frame[4];
    if (frame.length >= 1) return frame[0];
    return 0;
  }

  static String? _extractNrc(Uint8List frame) {
    // Negative response: [0x80|len, tgt, src, len, 0x7F, svcId, NRC]
    if (frame.length >= 7 && frame[4] == 0x7F) {
      return frame[6].toRadixString(16).toUpperCase().padLeft(2, '0');
    }
    return null;
  }

  static String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');

  static String _describeService(int serviceId, FrameDirection dir, String? nrc) {
    if (nrc != null) return 'Negative Response [NRC 0x$nrc] — ${_nrcDescription(nrc)}';
    final svcHex = serviceId.toRadixString(16).toUpperCase().padLeft(2, '0');
    final name = _serviceNames[serviceId] ?? 'Unknown Service 0x$svcHex';
    return dir == FrameDirection.tx ? '→ $name Request' : '← $name Response';
  }

  static String _nrcDescription(String nrc) => switch (nrc) {
        '10' => 'generalReject',
        '11' => 'serviceNotSupported',
        '12' => 'subFunctionNotSupported',
        '21' => 'busy',
        '22' => 'conditionsNotCorrect',
        '23' => 'routineNotComplete',
        '24' => 'requestSequenceError',
        '31' => 'requestOutOfRange',
        '33' => 'securityAccessDenied',
        '35' => 'invalidKey',
        '36' => 'exceedNumberOfAttempts',
        '37' => 'requiredTimeDelayNotExpired',
        '40' => 'downloadNotAccepted',
        '71' => 'transferDataSuspended',
        '72' => 'generalProgrammingFailure',
        '73' => 'wrongBlockSequenceCounter',
        '78' => 'requestCorrectlyReceived_ResponsePending',
        '80' => 'serviceNotSupportedInActiveSession',
        _ => 'unknownNRC',
      };

  static const Map<int, String> _serviceNames = {
    0x10: 'StartDiagnosticSession',
    0x11: 'ECUReset',
    0x14: 'ClearDiagnosticInformation',
    0x17: 'ReadStatusOfDTC',
    0x18: 'ReadDTCByStatus',
    0x1A: 'ReadEcuIdentification',
    0x20: 'StopDiagnosticSession',
    0x21: 'ReadDataByLocalIdentifier',
    0x22: 'ReadDataByCommonIdentifier',
    0x23: 'ReadMemoryByAddress',
    0x27: 'SecurityAccess',
    0x2C: 'DynamicallyDefineLocalId',
    0x2E: 'WriteDataByCommonIdentifier',
    0x30: 'InputOutputControlByLocalIdentifier',
    0x31: 'StartRoutineByLocalIdentifier',
    0x32: 'StopRoutineByLocalIdentifier',
    0x33: 'RequestRoutineResultsByLocalIdentifier',
    0x34: 'RequestDownload',
    0x36: 'TransferData',
    0x37: 'RequestTransferExit',
    0x3D: 'WriteMemoryByAddress',
    0x3E: 'TesterPresent',
    0x81: 'StartCommunication',
    0x82: 'StopCommunication',
    0x83: 'AccessTimingParameter',
  };

  static KwpFrameEntry _rowToEntry(Map<String, dynamic> row) => KwpFrameEntry(
        id: row['id'] as int,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        direction: (row['direction'] as String) == 'TX'
            ? FrameDirection.tx
            : FrameDirection.rx,
        serviceId: row['service_id'] as int,
        dataHex: row['data_hex'] as String,
        nrcCode: row['nrc_code'] as String?,
        description: row['description'] as String,
      );
}
