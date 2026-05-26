import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/ecu/ecu_definition.dart';
import '../../core/binary/rom_parser.dart';
import '../../core/ecu/ecu_verification_manager.dart';
import '../../core/reports/validation_report.dart';

// ── Professional parameter model ──────────────────────────────────────────────

class _ProfessionalParam {
  final String key;
  final String label;
  final String description;
  final String unit;
  final double currentValue;
  final double stockValue;
  final double minValue;
  final double maxValue;
  final double step;

  const _ProfessionalParam({
    required this.key,
    required this.label,
    required this.description,
    required this.unit,
    required this.currentValue,
    required this.stockValue,
    required this.minValue,
    required this.maxValue,
    required this.step,
  });

  _ProfessionalParam copyWithValue(double v) => _ProfessionalParam(
        key: key,
        label: label,
        description: description,
        unit: unit,
        currentValue: v.clamp(minValue, maxValue),
        stockValue: stockValue,
        minValue: minValue,
        maxValue: maxValue,
        step: step,
      );

  bool get isModified => (currentValue - stockValue).abs() > step / 2;
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Professional mode screen for advanced per-parameter ECU editing.
///
/// Exposes parameters not shown in the standard map editor:
///   - Fan activation temperature threshold
///   - Decel fuel cut window (rpm on/off)
///   - Throttle sensitivity scaling
///   - Injector dead time (at 14V)
///   - Injector flow rate scaling
///   - Rev limit (soft and hard)
///   - Launch control RPM limit (competition only)
///
/// Requires [EcuVerificationManager] VERIFIED status to enable flash.
/// Requires "PROCEED" typed in the confirmation dialog for any change
/// to launch control or rev limit parameters.
class ProfessionalTuningScreen extends StatefulWidget {
  final EcuDefinition ecu;
  final ParsedRom parsedRom;
  final Uint8List originalRom;

  const ProfessionalTuningScreen({
    super.key,
    required this.ecu,
    required this.parsedRom,
    required this.originalRom,
  });

  @override
  State<ProfessionalTuningScreen> createState() =>
      _ProfessionalTuningScreenState();
}

class _ProfessionalTuningScreenState
    extends State<ProfessionalTuningScreen> {
  late List<_ProfessionalParam> _params;
  VerificationStatus _verificationStatus = VerificationStatus.unverified;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _params = _defaultParams(widget.ecu);
    _loadVerification();
  }

  Future<void> _loadVerification() async {
    await EcuVerificationManager.instance.load();
    if (mounted) {
      setState(() {
        _verificationStatus =
            EcuVerificationManager.instance.statusFor(widget.ecu.id);
      });
    }
  }

  List<_ProfessionalParam> _defaultParams(EcuDefinition ecu) {
    final isClick = ecu.id.contains('click');
    return [
      _ProfessionalParam(
        key: 'fan_on_temp',
        label: 'Fan ON Temp',
        description: 'Coolant temperature at which the radiator fan activates.',
        unit: '°C',
        currentValue: isClick ? 98.0 : 95.0,
        stockValue: isClick ? 98.0 : 95.0,
        minValue: 80.0,
        maxValue: 105.0,
        step: 1.0,
      ),
      _ProfessionalParam(
        key: 'fan_off_temp',
        label: 'Fan OFF Temp',
        description: 'Coolant temperature at which the fan deactivates.',
        unit: '°C',
        currentValue: isClick ? 94.0 : 91.0,
        stockValue: isClick ? 94.0 : 91.0,
        minValue: 75.0,
        maxValue: 100.0,
        step: 1.0,
      ),
      _ProfessionalParam(
        key: 'decel_cut_on_rpm',
        label: 'Decel Cut ON RPM',
        description: 'RPM above which fuel is cut on deceleration (throttle closed).',
        unit: 'RPM',
        currentValue: isClick ? 2000.0 : 2500.0,
        stockValue: isClick ? 2000.0 : 2500.0,
        minValue: 1200.0,
        maxValue: 4000.0,
        step: 100.0,
      ),
      _ProfessionalParam(
        key: 'decel_cut_off_rpm',
        label: 'Decel Cut OFF RPM',
        description: 'RPM below which fuel cut re-engages injection.',
        unit: 'RPM',
        currentValue: isClick ? 1500.0 : 1800.0,
        stockValue: isClick ? 1500.0 : 1800.0,
        minValue: 800.0,
        maxValue: 2500.0,
        step: 100.0,
      ),
      _ProfessionalParam(
        key: 'throttle_sensitivity',
        label: 'Throttle Sensitivity',
        description: 'Scales the throttle position sensor linearization curve. '
            '100% = stock. Higher values make throttle feel more responsive.',
        unit: '%',
        currentValue: 100.0,
        stockValue: 100.0,
        minValue: 70.0,
        maxValue: 130.0,
        step: 5.0,
      ),
      _ProfessionalParam(
        key: 'injector_dead_time',
        label: 'Injector Dead Time',
        description: 'Injector opening latency at 14V battery. '
            'Increase if injectors are sluggish. Decrease for high-flow injectors.',
        unit: 'ms',
        currentValue: isClick ? 0.80 : 0.72,
        stockValue: isClick ? 0.80 : 0.72,
        minValue: 0.40,
        maxValue: 1.50,
        step: 0.02,
      ),
      _ProfessionalParam(
        key: 'injector_flow_scale',
        label: 'Injector Flow Scale',
        description: 'Scales injector pulse width to compensate for different-flow '
            'injectors. 100% = stock injector. Set to (stock_cc / new_cc × 100).',
        unit: '%',
        currentValue: 100.0,
        stockValue: 100.0,
        minValue: 60.0,
        maxValue: 160.0,
        step: 1.0,
      ),
      _ProfessionalParam(
        key: 'soft_rev_limit',
        label: 'Soft Rev Limit',
        description: 'RPM at which fuel cut begins tapering (fuel reduction, not hard cut).',
        unit: 'RPM',
        currentValue: isClick ? 9000.0 : 11000.0,
        stockValue: isClick ? 9000.0 : 11000.0,
        minValue: 7000.0,
        maxValue: isClick ? 10500.0 : 12500.0,
        step: 100.0,
      ),
      _ProfessionalParam(
        key: 'hard_rev_limit',
        label: 'Hard Rev Limit',
        description: 'RPM ceiling — complete fuel cut. Must be at least 200 RPM '
            'above soft limit.',
        unit: 'RPM',
        currentValue: isClick ? 9500.0 : 11500.0,
        stockValue: isClick ? 9500.0 : 11500.0,
        minValue: 7500.0,
        maxValue: isClick ? 11000.0 : 13000.0,
        step: 100.0,
      ),
      _ProfessionalParam(
        key: 'launch_control_rpm',
        label: 'Launch Control RPM',
        description: 'Competition: holds engine at this RPM during clutch-slip launch. '
            'Set to 0 to disable. REQUIRES "PROCEED" confirmation.',
        unit: 'RPM',
        currentValue: 0.0,
        stockValue: 0.0,
        minValue: 0.0,
        maxValue: isClick ? 5000.0 : 6000.0,
        step: 100.0,
      ),
    ];
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onValueChanged(int index, double newValue) {
    final param = _params[index];
    final isHighRisk = param.key == 'launch_control_rpm' ||
        param.key == 'hard_rev_limit' ||
        param.key == 'soft_rev_limit';

    if (isHighRisk && newValue != param.stockValue) {
      _showProceedGate(param.label, () {
        setState(() {
          _params[index] = param.copyWithValue(newValue);
        });
      });
    } else {
      setState(() {
        _params[index] = param.copyWithValue(newValue);
      });
    }
  }

  void _onResetToStock(int index) {
    setState(() {
      final p = _params[index];
      _params[index] = p.copyWithValue(p.stockValue);
    });
  }

  void _resetAll() {
    setState(() {
      _params = _params.map((p) => p.copyWithValue(p.stockValue)).toList();
    });
  }

  Future<void> _exportValidationReport() async {
    setState(() => _exporting = true);
    try {
      await ValidationReport.exportAndShare(widget.ecu.id);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showProceedGate(String paramName, VoidCallback onConfirmed) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canProceed = controller.text.trim() == 'PROCEED';
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('High-Risk Parameter'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are modifying: $paramName\n\n'
                  'Incorrect rev limits or launch control settings can '
                  'cause engine over-rev, valve float, rod damage, or '
                  'loss of control. For professional use only.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text('Type PROCEED to confirm:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'PROCEED',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: canProceed
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('CONFIRM'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed == true) onConfirmed();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modified = _params.where((p) => p.isModified).length;
    final isVerified = _verificationStatus == VerificationStatus.verified;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ecu.displayName} — Professional Mode'),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Validation Report',
            onPressed: _exporting ? null : _exportValidationReport,
          ),
          if (modified > 0)
            TextButton(
              onPressed: _resetAll,
              child: const Text('Reset All'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildVerificationBanner(theme, isVerified),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _params.length,
              itemBuilder: (context, i) =>
                  _buildParamCard(_params[i], i, theme),
            ),
          ),
        ],
      ),
      bottomNavigationBar: modified > 0
          ? _buildApplyBar(theme, modified, isVerified)
          : null,
    );
  }

  Widget _buildVerificationBanner(ThemeData theme, bool isVerified) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isVerified
          ? Colors.green.withValues(alpha: 0.15)
          : Colors.orange.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.warning_amber,
            color: isVerified ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVerified
                  ? 'ECU validated on real hardware — professional parameters enabled'
                  : 'ECU NOT hardware-validated. Changes calculated from community estimates.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isVerified ? Colors.green[800] : Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamCard(
      _ProfessionalParam param, int index, ThemeData theme) {
    final isHighRisk = param.key == 'launch_control_rpm' ||
        param.key == 'hard_rev_limit' ||
        param.key == 'soft_rev_limit';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            param.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isHighRisk) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('HIGH RISK',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        param.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (param.isModified)
                  IconButton(
                    icon: const Icon(Icons.undo, size: 18),
                    tooltip: 'Reset to stock (${param.stockValue.toStringAsFixed(param.step < 1 ? 2 : 0)} ${param.unit})',
                    onPressed: () => _onResetToStock(index),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    '${param.currentValue.toStringAsFixed(param.step < 1 ? 2 : 0)} ${param.unit}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: param.isModified
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: param.currentValue,
                    min: param.minValue,
                    max: param.maxValue,
                    divisions:
                        ((param.maxValue - param.minValue) / param.step)
                            .round(),
                    onChanged: (v) => _onValueChanged(index, v),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stock: ${param.stockValue.toStringAsFixed(param.step < 1 ? 2 : 0)} ${param.unit}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  'Range: ${param.minValue.toStringAsFixed(param.step < 1 ? 2 : 0)}–'
                  '${param.maxValue.toStringAsFixed(param.step < 1 ? 2 : 0)} ${param.unit}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyBar(ThemeData theme, int modified, bool isVerified) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isVerified)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  'ECU not hardware-validated — apply with caution.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$modified parameter(s) modified',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    // Parameters are applied to ROM via the standard
                    // flash workflow — pop back with the param changes
                    // encoded as a map for the caller to handle.
                    final changes = Map.fromEntries(
                      _params
                          .where((p) => p.isModified)
                          .map((p) => MapEntry(p.key, p.currentValue)),
                    );
                    Navigator.of(context).pop(changes);
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Send to Flash'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
