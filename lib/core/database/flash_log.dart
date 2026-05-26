import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/binary/rom_diff.dart';
import '../../core/flash/flash_engine.dart';

// ── Log entry model ───────────────────────────────────────────────────────────

class FlashLogEntry {
  final int? id;
  final String ecuId;
  final String ecuName;
  final DateTime timestamp;
  final bool success;
  final FlashStage finalStage;
  final int bytesChanged;
  final int mapsAffected;
  final String diffSummary;
  final String? errorDetail;
  final String backupPath;

  const FlashLogEntry({
    this.id,
    required this.ecuId,
    required this.ecuName,
    required this.timestamp,
    required this.success,
    required this.finalStage,
    required this.bytesChanged,
    required this.mapsAffected,
    required this.diffSummary,
    this.errorDetail,
    required this.backupPath,
  });

  Map<String, dynamic> toMap() => {
        'ecu_id': ecuId,
        'ecu_name': ecuName,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'success': success ? 1 : 0,
        'final_stage': finalStage.name,
        'bytes_changed': bytesChanged,
        'maps_affected': mapsAffected,
        'diff_summary': diffSummary,
        'error_detail': errorDetail,
        'backup_path': backupPath,
      };

  static FlashLogEntry fromMap(Map<String, dynamic> m) => FlashLogEntry(
        id: m['id'] as int?,
        ecuId: m['ecu_id'] as String,
        ecuName: m['ecu_name'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
        success: (m['success'] as int) == 1,
        finalStage: FlashStage.values.firstWhere(
          (s) => s.name == m['final_stage'],
          orElse: () => FlashStage.failed,
        ),
        bytesChanged: m['bytes_changed'] as int,
        mapsAffected: m['maps_affected'] as int,
        diffSummary: m['diff_summary'] as String,
        errorDetail: m['error_detail'] as String?,
        backupPath: m['backup_path'] as String,
      );
}

// ── Flash Log ─────────────────────────────────────────────────────────────────

/// SQLite-backed audit log for all flash attempts, with PDF export.
class FlashLog {
  static const String _dbName = 'flash_log.db';
  static const String _table = 'flash_attempts';

  Database? _db;

  Future<Database> _open() async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), _dbName),
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ecu_id TEXT NOT NULL,
          ecu_name TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          success INTEGER NOT NULL,
          final_stage TEXT NOT NULL,
          bytes_changed INTEGER NOT NULL,
          maps_affected INTEGER NOT NULL,
          diff_summary TEXT NOT NULL,
          error_detail TEXT,
          backup_path TEXT NOT NULL
        )
      '''),
    );
    return _db!;
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  /// Log a completed flash attempt. Returns the inserted row ID.
  Future<int> logAttempt({
    required String ecuId,
    required String ecuName,
    required bool success,
    required FlashStage finalStage,
    required DiffResult diff,
    required String backupPath,
    String? errorDetail,
  }) async {
    final db = await _open();
    final entry = FlashLogEntry(
      ecuId: ecuId,
      ecuName: ecuName,
      timestamp: DateTime.now(),
      success: success,
      finalStage: finalStage,
      bytesChanged: diff.allDiffs.length,
      mapsAffected: diff.mapDiffs.length,
      diffSummary: _buildDiffSummary(diff),
      errorDetail: errorDetail,
      backupPath: backupPath,
    );
    return db.insert(_table, entry.toMap());
  }

  /// Return all log entries, newest first.
  Future<List<FlashLogEntry>> getAllEntries() async {
    final db = await _open();
    final rows = await db.query(_table, orderBy: 'timestamp DESC');
    return rows.map(FlashLogEntry.fromMap).toList();
  }

  /// Return entries for a specific ECU, newest first.
  Future<List<FlashLogEntry>> getEntriesForEcu(String ecuId) async {
    final db = await _open();
    final rows = await db.query(
      _table,
      where: 'ecu_id = ?',
      whereArgs: [ecuId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(FlashLogEntry.fromMap).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── PDF export ─────────────────────────────────────────────────────────────

  /// Export all log entries to a PDF and trigger the system share/print dialog.
  Future<void> exportToPdf() async {
    final entries = await getAllEntries();
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'MotoRemap Pro — Flash Session Log',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated: ${_formatDate(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        ...entries.map(_buildEntryWidget),
      ],
    ));

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'flash_log_${_formatDateCompact(DateTime.now())}.pdf',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _buildDiffSummary(DiffResult diff) {
    final buf = StringBuffer();
    for (final md in diff.mapDiffs) {
      buf.write('${md.mapName}: ${md.diffs.length} bytes. ');
    }
    if (diff.unmappedDiffs.isNotEmpty) {
      buf.write('Unmapped: ${diff.unmappedDiffs.length} bytes.');
    }
    return buf.toString().trim();
  }

  static pw.Widget _buildEntryWidget(FlashLogEntry e) {
    final statusColor = e.success ? PdfColors.green : PdfColors.red;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                e.ecuName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  e.success ? 'SUCCESS' : 'FAILED',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text('Date: ${_formatDate(e.timestamp)}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Stage: ${e.finalStage.name}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Changed: ${e.bytesChanged} bytes across ${e.mapsAffected} map(s)',
              style: const pw.TextStyle(fontSize: 9)),
          if (e.diffSummary.isNotEmpty)
            pw.Text('Diff: ${e.diffSummary}',
                style: const pw.TextStyle(fontSize: 9)),
          if (e.errorDetail != null)
            pw.Text('Error: ${e.errorDetail}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.red)),
          pw.Text('Backup: ${e.backupPath}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${_p2(dt.month)}-${_p2(dt.day)} ${_p2(dt.hour)}:${_p2(dt.minute)}';

  static String _formatDateCompact(DateTime dt) =>
      '${dt.year}${_p2(dt.month)}${_p2(dt.day)}_${_p2(dt.hour)}${_p2(dt.minute)}';

  static String _p2(int n) => n.toString().padLeft(2, '0');
}
