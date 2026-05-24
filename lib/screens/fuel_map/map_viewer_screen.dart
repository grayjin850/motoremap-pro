import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../models/fuel_map.dart';
import '../../models/motorcycle_model.dart';
import '../../models/tune_profile.dart';

enum MapType { fuel, ignition }

enum _CellStatus { none, safe, caution, danger, vva }

class MapViewerScreen extends ConsumerStatefulWidget {
  final MapType mapType;
  const MapViewerScreen({super.key, required this.mapType});

  @override
  ConsumerState<MapViewerScreen> createState() => _MapViewerScreenState();
}

class _MapViewerScreenState extends ConsumerState<MapViewerScreen> {
  MotorcycleModel? _model;
  TuneProfile? _profile;
  bool _isLoading = true;
  bool _showSafetyColors = true;
  bool _hasChanges = false;
  bool _isSaving = false;

  // 12x12 editable copy: [tpsIndex][rpmIndex]
  late List<List<double>> _mapData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final modelId = prefs.getString('selected_model_id');
    final profileId = prefs.getString('selected_profile_id');

    if (modelId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final model = await DbHelper.getMotorcycleById(modelId);
    final profile = profileId != null ? await DbHelper.getProfileById(profileId) : null;

    if (mounted) {
      setState(() {
        _model = model;
        _profile = profile;
        // getters return fresh parsed lists each call — safe to hold directly
        _mapData = profile != null
            ? (widget.mapType == MapType.fuel ? profile.fuelMap : profile.ignitionMap)
            : List.generate(12, (_) => List.filled(12, 0.0));
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Cell status
  // ---------------------------------------------------------------------------

  _CellStatus _cellStatus(int tpsIdx, int rpmIdx) {
    if (!_showSafetyColors) return _CellStatus.none;
    final value = _mapData[tpsIdx][rpmIdx];

    if (widget.mapType == MapType.fuel) {
      if (value >= 12.8 && value <= 13.8) return _CellStatus.safe;
      if (value >= 12.0 && value <= 14.7) return _CellStatus.caution;
      return _CellStatus.danger;
    } else {
      // VVA zone check first
      if (_model?.hasVva == true) {
        final rpm = FuelMap.rpmAxis[rpmIdx];
        final vva = _model!.vvaTransitionRpm;
        if (rpm >= vva - 200 && rpm <= vva + 200) return _CellStatus.vva;
      }
      final maxAdv = (_model?.maxTimingAdvance ?? 5).toDouble();
      if (value >= 0 && value <= maxAdv) return _CellStatus.safe;
      if (value > maxAdv || value < -3) return _CellStatus.danger;
      return _CellStatus.caution;
    }
  }

  Color _bgForStatus(_CellStatus s) => switch (s) {
        _CellStatus.none => AppColors.panel,
        _CellStatus.safe => AppColors.safe.withValues(alpha: 0.25),
        _CellStatus.caution => AppColors.warning.withValues(alpha: 0.25),
        _CellStatus.danger => AppColors.danger.withValues(alpha: 0.25),
        _CellStatus.vva => AppColors.vvaZone.withValues(alpha: 0.25),
      };

  Color _textForStatus(_CellStatus s) => switch (s) {
        _CellStatus.none => AppColors.textPrimary,
        _CellStatus.safe => AppColors.safe,
        _CellStatus.caution => AppColors.warning,
        _CellStatus.danger => AppColors.danger,
        _CellStatus.vva => AppColors.vvaZone,
      };

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _editCell(int tpsIdx, int rpmIdx) {
    final current = _mapData[tpsIdx][rpmIdx];
    final ctrl = TextEditingController(text: current.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          widget.mapType == MapType.fuel
              ? 'AFR — ${FuelMap.tpsAxis[tpsIdx]}% TPS / ${FuelMap.rpmAxis[rpmIdx]} RPM'
              : 'Timing — ${FuelMap.tpsAxis[tpsIdx]}% TPS / ${FuelMap.rpmAxis[rpmIdx]} RPM',
          style: const TextStyle(fontSize: 15),
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            widget.mapType == MapType.fuel
                ? 'Safe: ${_model?.safeAfrMin.toStringAsFixed(1) ?? "12.0"}–${_model?.safeAfrMax.toStringAsFixed(1) ?? "14.7"}'
                : 'Max advance: +${_model?.maxTimingAdvance ?? 5}° (CR ${_model?.compressionRatio ?? "?"}:1)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.mapType == MapType.fuel ? 'AFR' : 'Degrees (±)',
              suffixText: widget.mapType == MapType.ignition ? '°' : null,
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kanselahin'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text);
              if (parsed != null) {
                setState(() {
                  _mapData[tpsIdx][rpmIdx] = parsed;
                  _hasChanges = true;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('I-update'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_profile == null || !_hasChanges) return;
    setState(() => _isSaving = true);

    final updatedJson = jsonEncode(_mapData);
    final updated = TuneProfile(
      id: _profile!.id,
      motorcycleModelId: _profile!.motorcycleModelId,
      type: _profile!.type,
      nameTaglish: _profile!.nameTaglish,
      descriptionTaglish: _profile!.descriptionTaglish,
      afrTargetMid: _profile!.afrTargetMid,
      afrTargetWot: _profile!.afrTargetWot,
      timingAdvanceDeg: _profile!.timingAdvanceDeg,
      revLimitRaise: _profile!.revLimitRaise,
      removeSpeedLimiter: _profile!.removeSpeedLimiter,
      safetyScore: _profile!.safetyScore,
      expectedBenefits: _profile!.expectedBenefits,
      fuelConsumptionNote: _profile!.fuelConsumptionNote,
      fuelMapJson:
          widget.mapType == MapType.fuel ? updatedJson : _profile!.fuelMapJson,
      ignitionMapJson:
          widget.mapType == MapType.ignition ? updatedJson : _profile!.ignitionMapJson,
    );

    await DbHelper.insertProfile(updated);
    if (mounted) {
      setState(() {
        _profile = updated;
        _hasChanges = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Na-save ang mga pagbabago!')),
      );
    }
  }

  void _exportCsv() {
    final buf = StringBuffer();
    buf.write('TPS\\RPM,');
    buf.writeln(FuelMap.rpmAxis.join(','));
    for (int t = 0; t < 12; t++) {
      buf.write('${FuelMap.tpsAxis[t]}%,');
      buf.writeln(_mapData[t].map((v) => v.toStringAsFixed(2)).join(','));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV (${widget.mapType == MapType.fuel ? "Fuel" : "Ignition"}) na-generate — ${_mapData.length * _mapData[0].length} cells.'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final title =
        widget.mapType == MapType.fuel ? 'Fuel Map (AFR)' : 'Ignition Timing Map';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: Icon(_showSafetyColors ? Icons.palette : Icons.palette_outlined),
            tooltip: _showSafetyColors ? 'Safety colors: ON' : 'Safety colors: OFF',
            onPressed: () => setState(() => _showSafetyColors = !_showSafetyColors),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile info bar
          if (_profile != null) _buildProfileBar(),
          // Legend
          if (_showSafetyColors) _buildLegend(),
          // Map grid
          Expanded(child: _buildGrid()),
          // Footer
          if (_model != null) _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildProfileBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.panel,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _profile!.nameTaglish,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              if (_model != null)
                Text(
                  '${_model!.brand} ${_model!.model} ${_model!.variant}',
                  style:
                      const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
            ]),
          ),
          if (_hasChanges)
            TextButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('I-save'),
              onPressed: _isSaving ? null : _saveChanges,
            ),
        ]),
      );

  Widget _buildLegend() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: AppColors.surface,
        child: Row(children: [
          _LegendDot(
              color: AppColors.safe,
              label:
                  widget.mapType == MapType.fuel ? 'Safe AFR' : 'Safe timing'),
          const SizedBox(width: 12),
          const _LegendDot(color: AppColors.warning, label: 'Caution'),
          const SizedBox(width: 12),
          const _LegendDot(color: AppColors.danger, label: 'Danger'),
          if (widget.mapType == MapType.ignition &&
              _model?.hasVva == true) ...[
            const SizedBox(width: 12),
            const _LegendDot(color: AppColors.vvaZone, label: 'VVA zone'),
          ],
          const Spacer(),
          Text(
            'Tap cell to edit',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ]),
      );

  Widget _buildGrid() => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: RPM labels
              Row(children: [
                _MapCell.header('TPS\\RPM', width: 54),
                ...FuelMap.rpmAxis.map((rpm) => _MapCell.header(
                      rpm >= 1000
                          ? '${(rpm / 1000).toStringAsFixed(0)}k'
                          : '$rpm',
                    )),
              ]),
              // Data rows
              ...List.generate(12, (t) => Row(
                    children: [
                      _MapCell.rowHeader('${FuelMap.tpsAxis[t]}%'),
                      ...List.generate(12, (r) {
                        final status = _cellStatus(t, r);
                        final value = _mapData[t][r];
                        return GestureDetector(
                          onTap: () => _editCell(t, r),
                          child: _MapCell(
                            text: value.toStringAsFixed(1),
                            bg: _bgForStatus(status),
                            fg: _textForStatus(status),
                          ),
                        );
                      }),
                    ],
                  )),
            ],
          ),
        ),
      );

  Widget _buildFooter() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.surface,
        width: double.infinity,
        child: Text(
          widget.mapType == MapType.fuel
              ? 'Safe Reference Range: ${_model!.safeAfrMin.toStringAsFixed(1)}–${_model!.safeAfrMax.toStringAsFixed(1)} | Mid: ${_model!.safeAfrMid.toStringAsFixed(1)} | WOT: ${_model!.safeAfrWot.toStringAsFixed(1)}'
              : 'Max timing advance: +${_model!.maxTimingAdvance}° | Compression ratio: ${_model!.compressionRatio}:1',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      );
}

// ---------------------------------------------------------------------------
// Shared cell widget
// ---------------------------------------------------------------------------

class _MapCell extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final double width;
  final double height;

  const _MapCell({
    required this.text,
    required this.bg,
    required this.fg,
    this.width = 44,
    this.height = 36,
  });

  factory _MapCell.header(String text, {double width = 44}) => _MapCell(
        text: text,
        bg: AppColors.panel,
        fg: AppColors.textSecondary,
        width: width,
        height: 36,
      );

  factory _MapCell.rowHeader(String text) => _MapCell(
        text: text,
        bg: AppColors.surface,
        fg: AppColors.textSecondary,
        width: 54,
        height: 36,
      );

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
          textAlign: TextAlign.center,
        ),
      );
}

// ---------------------------------------------------------------------------
// Legend dot
// ---------------------------------------------------------------------------

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ]);
}
