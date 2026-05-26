import 'dart:async';
import 'dart:typed_data';
import '../protocol/kwp_session.dart';
import '../ecu/ecu_definition.dart';
import 'recovery_manager.dart';

enum FlashStage { idle, backingUp, erasing, writing, verifying, done, failed, recovering }

// Interruption type detected during flash
enum FlashInterruptionType { usbDisconnect, sessionTimeout, writeError, verifyMismatch }

class FlashProgress {
  final FlashStage stage;
  final int bytesProcessed;
  final int totalBytes;
  final String message;
  final String? errorDetail;

  const FlashProgress({
    required this.stage,
    required this.bytesProcessed,
    required this.totalBytes,
    required this.message,
    this.errorDetail,
  });

  double get fraction => totalBytes == 0 ? 0 : bytesProcessed / totalBytes;
}

typedef FlashProgressCallback = void Function(FlashProgress progress);

/// Full ECU flash pipeline: backup → erase → write → verify → recovery on fail.
///
/// Flashing is WIRED-ONLY (OpenPort 2.0 K-Line). This class must never be
/// called with a Bluetooth adapter.
class FlashEngine {
  static const int _chunkSize = 128;

  // KWP2000 service IDs
  static const int _svcEraseMemory = 0x31;   // RequestRoutineByLocalId
  static const int _svcTransferData = 0x36;  // TransferData
  static const int _svcTransferExit = 0x37;  // RequestTransferExit
  static const int _svcRequestDownload = 0x34;

  final KwpSession session;
  final EcuDefinition ecu;
  final RecoveryManager recoveryManager;

  const FlashEngine({
    required this.session,
    required this.ecu,
    required this.recoveryManager,
  });

  /// Execute the full flash pipeline.
  ///
  /// [originalRom] must be the backup ROM read before any edits.
  /// [modifiedRom] is the checksum-corrected patched ROM ready to write.
  /// [onProgress] is called at every significant step.
  ///
  /// Returns true if flash + verify succeeded.
  /// On failure the backup is automatically restored.
  Future<bool> flash({
    required Uint8List originalRom,
    required Uint8List modifiedRom,
    required FlashProgressCallback onProgress,
  }) async {
    // ── 1. Backup ────────────────────────────────────────────────────────────
    onProgress(const FlashProgress(
      stage: FlashStage.backingUp,
      bytesProcessed: 0,
      totalBytes: 1,
      message: 'Saving backup before flash...',
    ));

    await recoveryManager.saveBackup(originalRom, ecu);

    onProgress(const FlashProgress(
      stage: FlashStage.backingUp,
      bytesProcessed: 1,
      totalBytes: 1,
      message: 'Backup saved.',
    ));

    // ── 2. Erase ─────────────────────────────────────────────────────────────
    onProgress(FlashProgress(
      stage: FlashStage.erasing,
      bytesProcessed: 0,
      totalBytes: ecu.romSizeBytes,
      message: 'Erasing ECU flash memory...',
    ));

    try {
      await _eraseRom();
    } catch (e) {
      onProgress(FlashProgress(
        stage: FlashStage.failed,
        bytesProcessed: 0,
        totalBytes: ecu.romSizeBytes,
        message: 'Erase failed — no changes made to ECU',
        errorDetail: e.toString(),
      ));
      return false;
    }

    // ── 3. Write ─────────────────────────────────────────────────────────────
    onProgress(FlashProgress(
      stage: FlashStage.writing,
      bytesProcessed: 0,
      totalBytes: ecu.romSizeBytes,
      message: 'Writing new ROM...',
    ));

    try {
      await _writeRom(modifiedRom, onProgress);
    } on FlashInterruptionException catch (e) {
      // USB disconnect / timeout mid-write — erase already committed, must recover
      final stage = e.type == FlashInterruptionType.usbDisconnect
          ? 'USB DISCONNECTED'
          : 'SESSION TIMEOUT';
      onProgress(FlashProgress(
        stage: FlashStage.recovering,
        bytesProcessed: e.lastWrittenOffset,
        totalBytes: ecu.romSizeBytes,
        message: '$stage at ${e.lastWrittenOffset ~/ 1024} KB — '
            'recovering from backup...',
        errorDetail: e.toString(),
      ));
      // Wait briefly before recovery — give USB time to settle if reconnected
      await Future.delayed(const Duration(seconds: 2));
      await _attemptRecovery(originalRom, onProgress);
      return false;
    } catch (e) {
      // Erase has already happened — must recover
      onProgress(FlashProgress(
        stage: FlashStage.recovering,
        bytesProcessed: 0,
        totalBytes: ecu.romSizeBytes,
        message: 'Write failed — recovering from backup...',
        errorDetail: e.toString(),
      ));
      await _attemptRecovery(originalRom, onProgress);
      return false;
    }

    // ── 4. Verify ─────────────────────────────────────────────────────────────
    onProgress(FlashProgress(
      stage: FlashStage.verifying,
      bytesProcessed: 0,
      totalBytes: ecu.romSizeBytes,
      message: 'Verifying written ROM...',
    ));

    Uint8List? readback;
    try {
      readback = await _readbackRom(onProgress);
    } catch (e) {
      onProgress(FlashProgress(
        stage: FlashStage.recovering,
        bytesProcessed: 0,
        totalBytes: ecu.romSizeBytes,
        message: 'Verify read-back failed — recovering...',
        errorDetail: e.toString(),
      ));
      await _attemptRecovery(originalRom, onProgress);
      return false;
    }

    if (!_verifyReadback(modifiedRom, readback)) {
      onProgress(FlashProgress(
        stage: FlashStage.recovering,
        bytesProcessed: 0,
        totalBytes: ecu.romSizeBytes,
        message: 'Verify mismatch — recovering from backup...',
        errorDetail: 'Read-back bytes did not match written ROM',
      ));
      await _attemptRecovery(originalRom, onProgress);
      return false;
    }

    onProgress(FlashProgress(
      stage: FlashStage.done,
      bytesProcessed: ecu.romSizeBytes,
      totalBytes: ecu.romSizeBytes,
      message: 'Flash complete. Verify passed.',
    ));
    return true;
  }

  // ── Internal flash steps ──────────────────────────────────────────────────

  Future<void> _eraseRom() async {
    // RequestDownload tells ECU we're about to write
    await session.sendService(
      _svcRequestDownload,
      Uint8List.fromList([
        0x00,                          // data format (uncompressed / unencrypted)
        (ecu.romSizeBytes >> 16) & 0xFF,
        (ecu.romSizeBytes >> 8) & 0xFF,
        ecu.romSizeBytes & 0xFF,
      ]),
    );

    // Erase routine (Keihin local ID 0x01; Shindengen may differ — identical frame)
    await session.sendService(
      _svcEraseMemory,
      Uint8List.fromList([0x01]),
    );

    // Erase can take up to 5 seconds on older Keihin ECUs
    await Future.delayed(const Duration(seconds: 5));
  }

  Future<void> _writeRom(
    Uint8List rom,
    FlashProgressCallback onProgress,
  ) async {
    session.pauseKeepAlive();
    try {
      var offset = 0;
      while (offset < rom.length) {
        final end = (offset + _chunkSize).clamp(0, rom.length);
        final chunk = rom.sublist(offset, end);

        // Block sequence counter wraps 0x00→0xFF
        final blockSeq = ((offset ~/ _chunkSize) & 0xFF);

        final request = Uint8List(chunk.length + 1);
        request[0] = blockSeq;
        request.setRange(1, chunk.length + 1, chunk);

        try {
          await session.sendService(_svcTransferData, request);
        } on TimeoutException {
          throw FlashInterruptionException(
            FlashInterruptionType.sessionTimeout,
            'USB timeout at offset 0x${offset.toRadixString(16)} — '
            'adapter may have disconnected mid-write.',
            lastWrittenOffset: offset,
          );
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('disconnected') ||
              msg.contains('port closed') ||
              msg.contains('usb error') ||
              msg.contains('ioexception')) {
            throw FlashInterruptionException(
              FlashInterruptionType.usbDisconnect,
              'USB adapter disconnected at offset '
              '0x${offset.toRadixString(16)} — ${rom.length - offset} bytes '
              'not written. Auto-recovery will restore backup.',
              lastWrittenOffset: offset,
            );
          }
          rethrow;
        }

        offset = end;

        onProgress(FlashProgress(
          stage: FlashStage.writing,
          bytesProcessed: offset,
          totalBytes: rom.length,
          message: 'Writing ${offset ~/ 1024} / ${rom.length ~/ 1024} KB...',
        ));
      }

      await session.sendService(_svcTransferExit, Uint8List(0));
    } finally {
      session.resumeKeepAlive();
    }
  }

  Future<Uint8List> _readbackRom(FlashProgressCallback onProgress) async {
    const svcReadMemory = 0x23;
    session.pauseKeepAlive();
    final buffer = BytesBuilder();
    try {
      var offset = 0;
      while (offset < ecu.romSizeBytes) {
        final remaining = ecu.romSizeBytes - offset;
        final len = remaining < _chunkSize ? remaining : _chunkSize;

        final response = await session.sendService(
          svcReadMemory,
          Uint8List.fromList([
            (offset >> 16) & 0xFF,
            (offset >> 8) & 0xFF,
            offset & 0xFF,
            len,
          ]),
        );

        if (response.length < len) {
          throw FlashException('Read-back returned short frame at offset 0x${offset.toRadixString(16)}');
        }
        buffer.add(response.sublist(0, len));
        offset += len;

        onProgress(FlashProgress(
          stage: FlashStage.verifying,
          bytesProcessed: offset,
          totalBytes: ecu.romSizeBytes,
          message: 'Verifying ${offset ~/ 1024} / ${ecu.romSizeBytes ~/ 1024} KB...',
        ));
      }
    } finally {
      session.resumeKeepAlive();
    }
    return buffer.toBytes();
  }

  bool _verifyReadback(Uint8List expected, Uint8List actual) {
    if (expected.length != actual.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) return false;
    }
    return true;
  }

  Future<void> _attemptRecovery(
    Uint8List backup,
    FlashProgressCallback onProgress,
  ) async {
    try {
      await _writeRom(backup, (p) => onProgress(FlashProgress(
        stage: FlashStage.recovering,
        bytesProcessed: p.bytesProcessed,
        totalBytes: p.totalBytes,
        message: 'Recovery: ${p.message}',
      )));
      onProgress(FlashProgress(
        stage: FlashStage.failed,
        bytesProcessed: backup.length,
        totalBytes: backup.length,
        message: 'Recovery complete. Original ROM restored.',
      ));
    } catch (e) {
      onProgress(FlashProgress(
        stage: FlashStage.failed,
        bytesProcessed: 0,
        totalBytes: backup.length,
        message: 'CRITICAL: Recovery also failed. ECU may be bricked.',
        errorDetail: e.toString(),
      ));
    }
  }
}

class FlashException implements Exception {
  final String message;
  const FlashException(this.message);
  @override
  String toString() => 'FlashException: $message';
}

/// Thrown when the flash pipeline is interrupted by USB disconnect or timeout.
///
/// Includes [lastWrittenOffset] so recovery logic knows how far the write
/// progressed — useful for diagnostics and partial-recovery strategies.
class FlashInterruptionException implements Exception {
  final FlashInterruptionType type;
  final String message;
  final int lastWrittenOffset;

  const FlashInterruptionException(
    this.type,
    this.message, {
    required this.lastWrittenOffset,
  });

  @override
  String toString() =>
      'FlashInterruptionException [${type.name}]: $message '
      '(last written offset: 0x${lastWrittenOffset.toRadixString(16)})';
}
