import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../protocol/kwp_session.dart';
import '../protocol/security_access.dart';
import 'ecu_definition.dart';

/// Progress callback: (bytesRead, totalBytes)
typedef RomReadProgress = void Function(int bytesRead, int totalBytes);

class RomReadException implements Exception {
  final String message;
  const RomReadException(this.message);
  @override
  String toString() => 'RomReadException: $message';
}

/// Reads the full ECU ROM binary over a KWP2000 session.
///
/// Process:
///   1. Unlock security access via SecurityAccess.unlock()
///   2. Read ROM in 128-byte chunks via service 0x23 (ReadMemoryByAddress)
///   3. Optionally save the raw binary to device storage
///
/// The keep-alive timer is paused during the bulk read to avoid frame
/// collisions on the K-Line bus.
class RomReader {
  RomReader._();

  /// KWP2000 service 0x23: ReadMemoryByAddress
  static const int _serviceReadMemory = 0x23;

  /// Maximum bytes per 0x23 request (ECU hardware limit for K-Line)
  static const int _chunkSize = 128;

  /// Read the full ECU ROM.
  ///
  /// [session] must be an active, authenticated KWP session.
  /// [ecu] provides the ROM size and security algorithm.
  /// [onProgress] is called after each 128-byte chunk.
  ///
  /// Returns the raw ROM as a [Uint8List] of [ecu.romSizeBytes] bytes.
  /// Throws [RomReadException] if the ECU does not support ROM read,
  /// or if a chunk read returns the wrong number of bytes.
  static Future<Uint8List> readRom(
    KwpSession session,
    EcuDefinition ecu, {
    RomReadProgress? onProgress,
  }) async {
    if (!ecu.capabilities.romRead) {
      throw RomReadException(
        'ECU "${ecu.displayName}" does not support ROM read',
      );
    }

    // Unlock security access before reading
    await SecurityAccess.unlock(session, ecu);

    final rom = Uint8List(ecu.romSizeBytes);
    int offset = 0;

    // Pause keep-alive — bulk read sends frames every ~5ms, keep-alive
    // would collide on the half-duplex K-Line bus
    session.pauseKeepAlive();

    try {
      while (offset < ecu.romSizeBytes) {
        final remaining = ecu.romSizeBytes - offset;
        final chunkLen = remaining < _chunkSize ? remaining : _chunkSize;

        final chunk = await _readChunk(session, offset, chunkLen);

        if (chunk.length != chunkLen) {
          throw RomReadException(
            'Chunk size mismatch at 0x${offset.toRadixString(16).padLeft(4, "0")}: '
            'expected $chunkLen bytes, got ${chunk.length}',
          );
        }

        rom.setRange(offset, offset + chunkLen, chunk);
        offset += chunkLen;
        onProgress?.call(offset, ecu.romSizeBytes);
      }
    } finally {
      session.resumeKeepAlive();
    }

    return rom;
  }

  /// Read a single 128-byte (or smaller) chunk via service 0x23.
  ///
  /// Request payload: [addrHigh, addrMid, addrLow, length]
  /// Response payload: [data bytes...] (length bytes)
  static Future<Uint8List> _readChunk(
    KwpSession session,
    int address,
    int length,
  ) async {
    final request = Uint8List(4);
    request[0] = (address >> 16) & 0xFF; // high byte
    request[1] = (address >> 8) & 0xFF;  // mid byte
    request[2] = address & 0xFF;          // low byte
    request[3] = length;                  // bytes to read

    return session.sendService(_serviceReadMemory, request);
  }

  /// Save a ROM binary to the app's documents/backups directory.
  ///
  /// Filename: {ecuId}_{ISO8601timestamp}.bin
  /// Returns the absolute file path.
  static Future<String> saveRomToDisk(
    Uint8List rom,
    EcuDefinition ecu,
  ) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory('${docsDir.path}/backups');

    if (!backupsDir.existsSync()) {
      backupsDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19); // 'yyyy-MM-ddTHH-mm-ss'

    final filename = '${ecu.id}_$timestamp.bin';
    final file = File('${backupsDir.path}/$filename');
    await file.writeAsBytes(rom, flush: true);

    return file.path;
  }
}
