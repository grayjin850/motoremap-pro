import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/ecu/ecu_definition.dart';
import '../../core/ecu/ecu_verification_manager.dart';
import '../../core/binary/rom_parser.dart';
import '../../core/tuning/tune_preset.dart';
import '../../core/tuning/preset_engine.dart';
import '../../core/tuning/click125i_presets.dart';
import '../../core/tuning/aerox155_presets.dart';

// ── Preset Selector Screen ────────────────────────────────────────────────────

/// Customer-facing screen for selecting and applying tuning presets.
///
/// Shows presets grouped by category, with full metadata including warnings,
/// side effects, confidence score, and verification status banner.
///
/// Returns the [Uint8List] of the modified ROM via Navigator.pop if the
/// tuner confirms and applies a preset.
class PresetSelectorScreen extends StatefulWidget {
  final EcuDefinition ecu;
  final ParsedRom parsedRom;
  final Uint8List originalRom;

  const PresetSelectorScreen({
    super.key,
    required this.ecu,
    required this.parsedRom,
    required this.originalRom,
  });

  @override
  State<PresetSelectorScreen> createState() => _PresetSelectorScreenState();
}

class _PresetSelectorScreenState extends State<PresetSelectorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  TunePreset? _selected;
  bool _applying = false;
  VerificationStatus _verificationStatus = VerificationStatus.unverified;

  List<TunePreset> get _presets {
    if (widget.ecu.id.contains('click')) return Click125iPresets.all;
    if (widget.ecu.id.contains('aerox')) return Aerox155Presets.all;
    return [];
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: PresetCategory.values.length, vsync: this);
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

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Apply preset ──────────────────────────────────────────────────────────

  Future<void> _applyPreset(TunePreset preset) async {
    final confirmed = await _showConfirmDialog(preset);
    if (!confirmed || !mounted) return;

    setState(() => _applying = true);
    try {
      final result = PresetEngine.apply(
        originalRom: widget.originalRom,
        parsedRom: widget.parsedRom,
        preset: preset,
        ecu: widget.ecu,
      );
      if (mounted) {
        Navigator.of(context).pop(result.modifiedRom);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply preset: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<bool> _showConfirmDialog(TunePreset preset) async {
    // Advanced presets (Racing / Drag / Aggressive VVA) require the mechanic
    // to type "PROCEED" before the apply button becomes active.
    if (preset.riskLevel == PresetRisk.advanced) {
      return await _showProceedGateDialog(preset) ?? false;
    }

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Apply ${preset.name}?'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_verificationStatus != VerificationStatus.verified)
                    _VerificationWarningCard(status: _verificationStatus),
                  const SizedBox(height: 12),
                  Text(
                    'This will modify ${preset.deltas.length} map zone(s).',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...preset.warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(w,
                                    style:
                                        const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Apply Preset'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// PROCEED gate — requires the mechanic to manually type "PROCEED" before
  /// an advanced/competition tune is applied. Prevents accidental application.
  Future<bool?> _showProceedGateDialog(TunePreset preset) {
    final controller = TextEditingController();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canProceed = controller.text.trim() == 'PROCEED';
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('ADVANCED: ${preset.name}')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'This is an ADVANCED competition tune. '
                      'It is intended for professional mechanics at racing '
                      'events only. Incorrect application may cause engine '
                      'damage, detonation, or piston failure.',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_verificationStatus != VerificationStatus.verified)
                    _VerificationWarningCard(status: _verificationStatus),
                  if (_verificationStatus != VerificationStatus.verified)
                    const SizedBox(height: 12),
                  Text(
                    'Requirements: ${preset.requiredMods.isEmpty ? 'None stated' : preset.requiredMods.join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Octane: ${preset.recommendedOctaneMin}+ RON MINIMUM',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...preset.warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.dangerous,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(w,
                                    style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                  const Text(
                    'Type PROCEED to confirm you are a professional mechanic '
                    'and understand the risks:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Type PROCEED',
                      border: const OutlineInputBorder(),
                      errorText: controller.text.isNotEmpty && !canProceed
                          ? 'Type exactly: PROCEED'
                          : null,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
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
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.red),
                child: const Text('APPLY ADVANCED TUNE'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presetsByCategory = <PresetCategory, List<TunePreset>>{};
    for (final p in _presets) {
      presetsByCategory.putIfAbsent(p.category, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ecu.displayName} — Presets'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: PresetCategory.values
              .map((c) => Tab(text: c.label))
              .toList(),
        ),
      ),
      body: Column(
        children: [
          _buildVerificationBanner(theme),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: PresetCategory.values.map((cat) {
                final presets = presetsByCategory[cat] ?? [];
                if (presets.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${cat.label} presets for this ECU',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: presets.length,
                  itemBuilder: (context, i) =>
                      _buildPresetCard(presets[i], theme),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected != null
          ? _buildApplyBar(theme)
          : null,
    );
  }

  Widget _buildVerificationBanner(ThemeData theme) {
    final isVerified = _verificationStatus == VerificationStatus.verified;
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
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVerified
                  ? 'ECU validated on real hardware — presets are safe to apply'
                  : 'ECU NOT hardware-validated — ROM offsets are community estimates. '
                      'Validate before flashing.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isVerified ? Colors.green[800] : Colors.orange[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(TunePreset preset, ThemeData theme) {
    final isSelected = _selected?.id == preset.id;
    final riskColor = switch (preset.riskLevel) {
      PresetRisk.safe => Colors.green,
      PresetRisk.caution => Colors.orange,
      PresetRisk.advanced => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() =>
            _selected = isSelected ? null : preset),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _RiskBadge(risk: preset.riskLevel, color: riskColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                preset.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _buildMetaRow(
                theme,
                '${preset.recommendedOctaneMin}+ RON',
                Icons.local_gas_station,
              ),
              _buildMetaRow(
                theme,
                'Confidence: ${(preset.confidenceScore * 100).toStringAsFixed(0)}%',
                Icons.analytics,
              ),
              if (preset.estimatedPowerGainPct != null)
                _buildMetaRow(
                  theme,
                  'Power: ${preset.estimatedPowerGainPct! > 0 ? '+' : ''}'
                      '${preset.estimatedPowerGainPct!.toStringAsFixed(0)}%',
                  Icons.speed,
                ),
              if (preset.estimatedFuelChangePct != null)
                _buildMetaRow(
                  theme,
                  'Fuel: ${preset.estimatedFuelChangePct! > 0 ? '+' : ''}'
                      '${preset.estimatedFuelChangePct!.toStringAsFixed(0)}%',
                  Icons.opacity,
                ),
              if (preset.requiredMods.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Requires: ${preset.requiredMods.join(', ')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (isSelected) ...[
                const Divider(height: 16),
                _buildExpandedDetails(preset, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(ThemeData theme, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(TunePreset preset, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailSection('AFR Strategy', preset.afrTargetExplanation, theme),
        if (preset.benefits.isNotEmpty)
          _bulletSection('Benefits', preset.benefits, Colors.green, theme),
        if (preset.sideEffects.isNotEmpty)
          _bulletSection('Side Effects', preset.sideEffects, Colors.orange, theme),
        if (preset.warnings.isNotEmpty)
          _bulletSection('Warnings', preset.warnings, Colors.red, theme),
      ],
    );
  }

  Widget _detailSection(String title, String body, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _bulletSection(
      String title, List<String> items, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(item,
                            style: theme.textTheme.bodySmall)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildApplyBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: ${_selected!.name}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_selected!.deltas.length} map zone(s) will be modified',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _applying ? null : () => _applyPreset(_selected!),
              child: _applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _RiskBadge extends StatelessWidget {
  final PresetRisk risk;
  final Color color;
  const _RiskBadge({required this.risk, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (risk) {
      PresetRisk.safe => 'SAFE',
      PresetRisk.caution => 'CAUTION',
      PresetRisk.advanced => 'ADVANCED',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _VerificationWarningCard extends StatelessWidget {
  final VerificationStatus status;
  const _VerificationWarningCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 16),
              SizedBox(width: 6),
              Text(
                'ECU Not Hardware-Validated',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status.description,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
