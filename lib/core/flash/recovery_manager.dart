import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../ecu/ecu_definition.dart';

/// Manages backup files: saves, lists, prunes to last 5, restores.
class RecoveryManager {
  static const int _maxBackups = 5;

  /// Save a ROM backup to {documents}/backups/{ecuId}_{timestamp}.bin.
  /// Automatically prunes older backups so at most [_maxBackups] are kept.
  Future<File> saveBackup(Uint8List rom, EcuDefinition ecu) async {
    final dir = await _backupDir();
    final ts = _timestamp();
    final file = File('${dir.path}/${ecu.id}_$ts.bin');
    await file.writeAsBytes(rom);
    await _pruneOldBackups(dir, ecu.id);
    return file;
  }

  /// List all available backups for [ecuId], newest first.
  Future<List<BackupEntry>> listBackups(String ecuId) async {
    final dir = await _backupDir();
    if (!dir.existsSync()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('${ecuId}_') && f.path.endsWith('.bin'))
        .toList();

    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    return files.map((f) {
      final name = f.uri.pathSegments.last;
      final stat = f.statSync();
      return BackupEntry(
        file: f,
        ecuId: ecuId,
        timestamp: stat.modified,
        sizeBytes: stat.size,
        fileName: name,
      );
    }).toList();
  }

  /// Read backup file contents.
  Future<Uint8List> loadBackup(BackupEntry entry) async {
    return entry.file.readAsBytes();
  }

  /// Delete a specific backup.
  Future<void> deleteBackup(BackupEntry entry) async {
    if (entry.file.existsSync()) await entry.file.delete();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backups');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _pruneOldBackups(Directory dir, String ecuId) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('${ecuId}_') && f.path.endsWith('.bin'))
        .toList();

    if (files.length <= _maxBackups) return;
    files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    final toDelete = files.sublist(0, files.length - _maxBackups);
    for (final f in toDelete) {
      await f.delete();
    }
  }
}

class BackupEntry {
  final File file;
  final String ecuId;
  final DateTime timestamp;
  final int sizeBytes;
  final String fileName;

  const BackupEntry({
    required this.file,
    required this.ecuId,
    required this.timestamp,
    required this.sizeBytes,
    required this.fileName,
  });

  String get displayName {
    final d = timestamp;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
