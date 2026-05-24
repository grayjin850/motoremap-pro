import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../models/motorcycle_model.dart';
import '../../core/database/db_helper.dart';

class ModelSelectorScreen extends ConsumerStatefulWidget {
  const ModelSelectorScreen({super.key});

  @override
  ConsumerState<ModelSelectorScreen> createState() =>
      _ModelSelectorScreenState();
}

class _ModelSelectorScreenState extends ConsumerState<ModelSelectorScreen> {
  List<MotorcycleModel> _allModels = [];
  bool _loading = true;

  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedYearRange;
  String? _selectedVariant;
  int _selectedLevel = 1;

  MotorcycleModel? get _matchedModel {
    if (_selectedBrand == null ||
        _selectedModel == null ||
        _selectedYearRange == null ||
        _selectedVariant == null) {
      return null;
    }
    return _allModels.firstWhere(
      (m) =>
          m.brand == _selectedBrand &&
          m.model == _selectedModel &&
          _yearRangeFor(m) == _selectedYearRange &&
          m.variant == _selectedVariant,
      orElse: () => _allModels.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final models = await DbHelper.getAllMotorcycles();
      if (mounted) {
        setState(() {
          _allModels = models;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _yearRangeFor(MotorcycleModel m) {
    final end = m.yearTo == 0 ? 'kasalukuyan' : m.yearTo.toString();
    return '${m.yearFrom}–$end';
  }

  List<String> get _brands {
    final seen = <String>{};
    return _allModels
        .map((m) => m.brand)
        .where(seen.add)
        .toList();
  }

  List<String> get _modelsForBrand {
    if (_selectedBrand == null) return [];
    final seen = <String>{};
    return _allModels
        .where((m) => m.brand == _selectedBrand)
        .map((m) => m.model)
        .where(seen.add)
        .toList();
  }

  List<String> get _yearRangesForModel {
    if (_selectedBrand == null || _selectedModel == null) return [];
    final seen = <String>{};
    return _allModels
        .where((m) => m.brand == _selectedBrand && m.model == _selectedModel)
        .map(_yearRangeFor)
        .where(seen.add)
        .toList();
  }

  List<String> get _variantsForModel {
    if (_selectedBrand == null ||
        _selectedModel == null ||
        _selectedYearRange == null) {
      return [];
    }
    final seen = <String>{};
    return _allModels
        .where(
          (m) =>
              m.brand == _selectedBrand &&
              m.model == _selectedModel &&
              _yearRangeFor(m) == _selectedYearRange,
        )
        .map((m) => m.variant)
        .where(seen.add)
        .toList();
  }

  Future<void> _confirmSelection() async {
    final model = _matchedModel;
    if (model == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model_id', model.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Pumili ng Motorsiklo',
          style: GoogleFonts.rajdhani(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _allModels.isEmpty
              ? Center(
                  child: Text(
                    'Walang datos ng motorsiklo.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDropdown(
                        label: 'Brand',
                        hint: 'Piliin ang brand',
                        value: _selectedBrand,
                        items: _brands,
                        enabled: true,
                        onChanged: (v) {
                          setState(() {
                            _selectedBrand = v;
                            _selectedModel = null;
                            _selectedYearRange = null;
                            _selectedVariant = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildDropdown(
                        label: 'Model',
                        hint: 'Piliin ang model',
                        value: _selectedModel,
                        items: _modelsForBrand,
                        enabled: _selectedBrand != null,
                        onChanged: (v) {
                          setState(() {
                            _selectedModel = v;
                            _selectedYearRange = null;
                            _selectedVariant = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildDropdown(
                        label: 'Taon',
                        hint: 'Piliin ang taon',
                        value: _selectedYearRange,
                        items: _yearRangesForModel,
                        enabled: _selectedModel != null,
                        onChanged: (v) {
                          setState(() {
                            _selectedYearRange = v;
                            _selectedVariant = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildDropdown(
                        label: 'Variant',
                        hint: 'Piliin ang variant',
                        value: _selectedVariant,
                        items: _variantsForModel,
                        enabled: _selectedYearRange != null,
                        onChanged: (v) {
                          setState(() {
                            _selectedVariant = v;
                          });
                        },
                      ),
                      if (_matchedModel != null) ...[
                        const SizedBox(height: 24),
                        _SpecCard(model: _matchedModel!),
                        const SizedBox(height: 16),
                        _ModificationLevelSelector(
                          model: _matchedModel!,
                          selectedLevel: _selectedLevel,
                          onLevelChanged: (l) =>
                              setState(() => _selectedLevel = l),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _confirmSelection,
                          child: Text(
                            'Piliin ang Motorsiklo na ito',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required bool enabled,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
          dropdownColor: AppColors.panel,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? AppColors.panel : AppColors.surface,
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Spec Card
// ---------------------------------------------------------------------------

class _SpecCard extends StatelessWidget {
  final MotorcycleModel model;

  const _SpecCard({required this.model});

  String get _yearRange {
    final end = model.yearTo == 0 ? 'kasalukuyan' : model.yearTo.toString();
    return '${model.yearFrom}–$end';
  }

  bool get _highCompression => model.compressionRatio >= 11.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.cardBorder),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.two_wheeler, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${model.brand} ${model.model} ${model.variant} ($_yearRange)',
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Engine specs
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _specRow(
                  'Engine',
                  '${model.displacement}cc ${model.valveSystem} ${model.valveCount}-valve'
                      '${model.hasVva ? ' VVA' : ''}',
                ),
                const SizedBox(height: 6),
                _compressionRow(),
                const SizedBox(height: 6),
                _specRow(
                  'Stock Rev Limit',
                  '${model.stockRevLimitSoft.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} RPM',
                ),
                const SizedBox(height: 6),
                _specRow(
                  'Stock Speed Limit',
                  '${model.stockSpeedLimit} km/h',
                ),
                const SizedBox(height: 6),
                _specRow('ECU Type', model.ecuType),
                const SizedBox(height: 6),
                _specRow('Flash Tool', model.flashTool),

                if (model.hasVva) ...[
                  const SizedBox(height: 10),
                  _vvaRow(),
                ],

                const SizedBox(height: 14),
                _safeRangesSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            '$label:',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compressionRow() {
    final label = _highCompression ? ' ⚠️ (HIGH — max timing +${model.maxTimingAdvance}°)' : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            'Compression:',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${model.compressionRatio}:1$label',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _highCompression ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _vvaRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.vvaZone.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.vvaZone.withValues(alpha: 0.4)),
      ),
      child: Text(
        'VVA Zone: ${model.vvaTransitionRpm - 200}–${model.vvaTransitionRpm + 200} RPM ⚠️ (handle carefully)',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.vvaZone,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _safeRangesSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SAFE REFERENCE RANGES:',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          _specRow(
            'AFR Range',
            '${model.safeAfrMin}–${model.safeAfrMax}',
          ),
          const SizedBox(height: 4),
          _specRow(
            'Max Timing Advance',
            '+${model.maxTimingAdvance}° (compression-derived)',
          ),
          const SizedBox(height: 4),
          _specRow(
            'Max Rev Raise',
            '${model.maxSafeRevRaise.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} RPM',
          ),
          if (model.hasVva) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    'VVA Zone:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${model.vvaTransitionRpm - 200}–${model.vvaTransitionRpm + 200} RPM ⚠️ (handle carefully)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.vvaZone,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modification Level Selector
// ---------------------------------------------------------------------------

class _ModificationLevelSelector extends StatelessWidget {
  final MotorcycleModel model;
  final int selectedLevel;
  final void Function(int) onLevelChanged;

  const _ModificationLevelSelector({
    required this.model,
    required this.selectedLevel,
    required this.onLevelChanged,
  });

  static const _levelLabels = {
    1: 'Remap only',
    2: '+Exhaust',
    3: '+Filter',
    4: 'Full bolt-on',
  };

  @override
  Widget build(BuildContext context) {
    final expectedSpeed = model.expectedSpeedByLevel[selectedLevel];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Antas ng Modipikasyon',
          style: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [1, 2, 3, 4].map((level) {
            final selected = level == selectedLevel;
            return Expanded(
              child: GestureDetector(
                onTap: () => onLevelChanged(level),
                child: Container(
                  margin: EdgeInsets.only(right: level < 4 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.cardBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'L$level',
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _levelLabels[level] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (expectedSpeed != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Inaasahang bilis (Level $selectedLevel): ${expectedSpeed.toStringAsFixed(0)} km/h',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
