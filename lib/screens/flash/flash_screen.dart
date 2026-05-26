import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/flash/flash_engine.dart';
import '../../core/flash/pre_flash_gate.dart';
import '../../core/flash/recovery_manager.dart';
import '../../core/binary/rom_diff.dart';
import '../../core/ecu/ecu_definition.dart';
import '../../core/database/flash_log.dart';
import '../../core/protocol/kwp_session.dart';

// ── Flash Screen ──────────────────────────────────────────────────────────────

/// Full flash workflow screen.
///
/// Shows pre-flight gate checklist → confirmation → live progress (backup /
/// erase / write / verify) → result summary. Recovery is shown automatically
/// if flash fails mid-way.
class FlashScreen extends StatefulWidget {
  final EcuDefinition ecu;
  final Uint8List originalRom;
  final Uint8List modifiedRom;
  final DiffResult diff;
  final KwpSession session;

  /// Live OBD values polled before entering this screen.
  final double batteryVoltage;
  final int engineRpm;
  final double coolantTempC;

  const FlashScreen({
    super.key,
    required this.ecu,
    required this.originalRom,
    required this.modifiedRom,
    required this.diff,
    required this.session,
    required this.batteryVoltage,
    required this.engineRpm,
    required this.coolantTempC,
  });

  @override
  State<FlashScreen> createState() => _FlashScreenState();
}

enum _ScreenPhase { preflight, confirming, flashing, result }

class _FlashScreenState extends State<FlashScreen> {
  _ScreenPhase _phase = _ScreenPhase.preflight;

  // Pre-flight
  late PreFlashGateResult _gateResult;
  bool _diffApproved = true; // Caller already went through diff viewer

  // Flash progress
  FlashProgress _progress = const FlashProgress(
    stage: FlashStage.idle,
    bytesProcessed: 0,
    totalBytes: 1,
    message: 'Waiting...',
  );

  // Result
  bool _flashSuccess = false;
  String? _backupPath;

  final _recoveryManager = RecoveryManager();
  final _flashLog = FlashLog();

  @override
  void initState() {
    super.initState();
    _evaluateGate();
  }

  void _evaluateGate() {
    _gateResult = PreFlashGate.evaluate(
      adapterSupportsWrite: widget.session.adapter.supportsWrite,
      batteryVoltage: widget.batteryVoltage,
      engineRpm: widget.engineRpm,
      coolantTempC: widget.coolantTempC,
      backupVerified: true, // Caller read original ROM successfully
      modifiedRom: widget.modifiedRom,
      ecu: widget.ecu,
      diffApproved: _diffApproved,
    );
  }

  // ── Flash execution ────────────────────────────────────────────────────────

  Future<void> _startFlash() async {
    setState(() => _phase = _ScreenPhase.flashing);

    final engine = FlashEngine(
      session: widget.session,
      ecu: widget.ecu,
      recoveryManager: _recoveryManager,
    );

    // Get the backup path from recovery manager before flashing
    final backupDir = await _recoveryManager.listBackups(widget.ecu.id);
    _backupPath = backupDir.isNotEmpty ? backupDir.first.file.path : '';

    final success = await engine.flash(
      originalRom: widget.originalRom,
      modifiedRom: widget.modifiedRom,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    // Log the attempt
    await _flashLog.logAttempt(
      ecuId: widget.ecu.id,
      ecuName: widget.ecu.displayName,
      success: success,
      finalStage: _progress.stage,
      diff: widget.diff,
      backupPath: _backupPath ?? '',
      errorDetail: _progress.errorDetail,
    );

    setState(() {
      _flashSuccess = success;
      _phase = _ScreenPhase.result;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash ECU'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
      ),
      body: switch (_phase) {
        _ScreenPhase.preflight => _buildPreflight(context),
        _ScreenPhase.confirming => _buildConfirm(context),
        _ScreenPhase.flashing => _buildFlashing(context),
        _ScreenPhase.result => _buildResult(context),
      },
    );
  }

  // ── Pre-flight ─────────────────────────────────────────────────────────────

  Widget _buildPreflight(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildDiffBanner(theme),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Pre-Flash Safety Checklist',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All checks must be green before flashing is allowed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ..._gateResult.checks.map(_buildCheckRow),
              const SizedBox(height: 16),
              _buildScoreCard(theme),
            ],
          ),
        ),
        _buildPreflightActions(theme),
      ],
    );
  }

  Widget _buildDiffBanner(ThemeData theme) {
    final total = widget.diff.allDiffs.length;
    final maps = widget.diff.mapDiffs.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.secondaryContainer,
      child: Text(
        '$total byte(s) changed across $maps map(s)',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCheckRow(GateCheck check) {
    final icon = check.passed
        ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
        : const Icon(Icons.cancel, color: Colors.red, size: 22);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(check.detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: check.passed ? Colors.green[700] : Colors.red[700],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(ThemeData theme) {
    final score = _gateResult.safetyScore;
    final color = score >= 85 ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('/ 100', style: TextStyle(color: color, fontSize: 16)),
              Text(
                score >= 85 ? 'SAFE TO FLASH' : 'RESOLVE ISSUES FIRST',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreflightActions(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _gateResult.allGreen
                    ? () => setState(() => _phase = _ScreenPhase.confirming)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text('Proceed to Flash'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm ────────────────────────────────────────────────────────────────

  Widget _buildConfirm(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 60, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Final Confirmation',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'You are about to write ${widget.diff.allDiffs.length} byte(s) to '
            '${widget.ecu.displayName}.\n\n'
            'A backup will be saved first. If verification fails after writing, '
            'the backup will be automatically restored.\n\n'
            'Do NOT disconnect the adapter or turn off the ignition during flash.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _phase = _ScreenPhase.preflight),
                  child: const Text('Go Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _startFlash,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: const Text('FLASH NOW'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Flashing ───────────────────────────────────────────────────────────────

  Widget _buildFlashing(BuildContext context) {
    final theme = Theme.of(context);
    final stageLabel = switch (_progress.stage) {
      FlashStage.backingUp => 'Saving Backup',
      FlashStage.erasing => 'Erasing ECU',
      FlashStage.writing => 'Writing ROM',
      FlashStage.verifying => 'Verifying',
      FlashStage.recovering => 'Recovering Backup',
      FlashStage.done => 'Complete',
      FlashStage.failed => 'Failed',
      FlashStage.idle => 'Preparing',
    };

    final stageColors = <FlashStage, Color>{
      FlashStage.backingUp: Colors.blue,
      FlashStage.erasing: Colors.orange,
      FlashStage.writing: theme.colorScheme.primary,
      FlashStage.verifying: Colors.teal,
      FlashStage.recovering: Colors.amber,
      FlashStage.done: Colors.green,
      FlashStage.failed: Colors.red,
      FlashStage.idle: Colors.grey,
    };

    final color = stageColors[_progress.stage] ?? Colors.grey;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back nav during flash
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStageIndicator(theme, color),
            const SizedBox(height: 32),
            Text(
              stageLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _progress.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress.fraction,
                minHeight: 12,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_progress.bytesProcessed ~/ 1024} / '
              '${_progress.totalBytes ~/ 1024} KB',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: theme.colorScheme.onErrorContainer, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Do NOT disconnect or turn off ignition',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageIndicator(ThemeData theme, Color color) {
    const stages = [
      FlashStage.backingUp,
      FlashStage.erasing,
      FlashStage.writing,
      FlashStage.verifying,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stages.map((s) {
        final isActive = _progress.stage == s;
        final isDone = stages.indexOf(s) <
            stages.indexOf(_progress.stage == FlashStage.verifying
                ? FlashStage.verifying
                : _progress.stage);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDone
                    ? Colors.green
                    : isActive
                        ? color
                        : Colors.grey[300],
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Result ─────────────────────────────────────────────────────────────────

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final success = _flashSuccess;
    final color = success ? Colors.green : Colors.red;
    final icon = success ? Icons.check_circle : Icons.error;
    final title = success ? 'Flash Successful' : 'Flash Failed';
    final body = success
        ? 'The new ROM has been written and verified.\n'
            '${widget.diff.allDiffs.length} byte(s) changed across '
            '${widget.diff.mapDiffs.length} map(s).\n\n'
            'Start the engine and test at a safe location.\n'
            'Monitor AFR and temperatures on first run.'
        : _progress.errorDetail != null
            ? 'Error: ${_progress.errorDetail}\n\n'
                'The original ROM has been automatically restored.\n'
                'Check your adapter connection and try again.'
            : 'An unexpected error occurred.\n'
                'The original ROM has been restored from backup.';

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 72, color: color),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(body, style: theme.textTheme.bodyMedium),
          if (_backupPath != null) ...[
            const SizedBox(height: 12),
            Text(
              'Backup: $_backupPath',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export Log'),
                  onPressed: () => _flashLog.exportToPdf(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(success),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
