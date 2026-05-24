import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../models/motorcycle_model.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<MotorcycleModel> _models = [];
  bool _isLoading = true;
  MotorcycleModel? _selected;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    final models = await DbHelper.getAllMotorcycles();
    if (mounted) {
      setState(() {
        _models = models;
        _isLoading = false;
        // Refresh selected if editing
        if (_selected != null) {
          _selected = models.firstWhere(
            (m) => m.id == _selected!.id,
            orElse: () => models.first,
          );
        }
      });
    }
  }

  void _selectModel(MotorcycleModel m) => setState(() => _selected = m);

  void _openEditSheet(MotorcycleModel m) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppColors.cardBorder),
      ),
      builder: (_) => _AdminEditSheet(model: m),
    );
    if (saved == true) _loadModels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Motorcycle Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _models.isEmpty
              ? const Center(
                  child: Text('Walang motorsiklo sa database.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : Column(children: [
                  // Safety floor notice
                  _buildSafetyFloorNotice(),

                  // Model list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _models.length,
                      itemBuilder: (_, i) => _ModelTile(
                        model: _models[i],
                        isSelected: _selected?.id == _models[i].id,
                        onTap: () => _selectModel(_models[i]),
                        onEdit: () => _openEditSheet(_models[i]),
                      ),
                    ),
                  ),
                ]),
    );
  }

  Widget _buildSafetyFloorNotice() => Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.lock_outline, color: AppColors.danger, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'SAFETY FLOOR: Ang max timing advance ay AWTOMATIKONG kalkulado '
              'mula sa compression ratio at HINDI maaaring i-override ng admin. '
              'Ito ay isang hard safety limit.',
              style: TextStyle(color: AppColors.danger, fontSize: 11),
            ),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Model tile
// ---------------------------------------------------------------------------

class _ModelTile extends StatelessWidget {
  final MotorcycleModel model;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ModelTile({
    required this.model,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${model.brand} ${model.model} ${model.variant}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '${model.yearFrom}${model.yearTo == 0 ? '–present' : '–${model.yearTo}'}  •  ${model.displacement}cc  •  ${model.valveSystem}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                _Chip(
                    label: 'Max Timing: +${model.maxTimingAdvance}° (LOCKED)',
                    color: AppColors.danger),
                _Chip(
                    label: 'AFR ${model.safeAfrMin}–${model.safeAfrMax}',
                    color: AppColors.safe),
                _Chip(
                    label: 'Rev ${model.stockRevLimitHard} RPM',
                    color: AppColors.warning),
              ]),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary, size: 20),
            onPressed: onEdit,
            tooltip: 'I-edit ang parameters',
          ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      );
}

// ---------------------------------------------------------------------------
// Admin edit bottom sheet
// ---------------------------------------------------------------------------

class _AdminEditSheet extends StatefulWidget {
  final MotorcycleModel model;
  const _AdminEditSheet({required this.model});

  @override
  State<_AdminEditSheet> createState() => _AdminEditSheetState();
}

class _AdminEditSheetState extends State<_AdminEditSheet> {
  late final TextEditingController _ecuTypeCtrl;
  late final TextEditingController _flashToolCtrl;
  late final TextEditingController _safeAfrMinCtrl;
  late final TextEditingController _safeAfrMaxCtrl;
  late final TextEditingController _safeAfrMidCtrl;
  late final TextEditingController _safeAfrWotCtrl;
  late final TextEditingController _revSoftCtrl;
  late final TextEditingController _revHardCtrl;
  late final TextEditingController _speedLimitCtrl;
  late final TextEditingController _maxRevRaiseCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _ecuTypeCtrl = TextEditingController(text: m.ecuType);
    _flashToolCtrl = TextEditingController(text: m.flashTool);
    _safeAfrMinCtrl = TextEditingController(text: m.safeAfrMin.toString());
    _safeAfrMaxCtrl = TextEditingController(text: m.safeAfrMax.toString());
    _safeAfrMidCtrl = TextEditingController(text: m.safeAfrMid.toString());
    _safeAfrWotCtrl = TextEditingController(text: m.safeAfrWot.toString());
    _revSoftCtrl = TextEditingController(text: m.stockRevLimitSoft.toString());
    _revHardCtrl = TextEditingController(text: m.stockRevLimitHard.toString());
    _speedLimitCtrl = TextEditingController(text: m.stockSpeedLimit.toString());
    _maxRevRaiseCtrl = TextEditingController(text: m.maxSafeRevRaise.toString());
  }

  @override
  void dispose() {
    _ecuTypeCtrl.dispose();
    _flashToolCtrl.dispose();
    _safeAfrMinCtrl.dispose();
    _safeAfrMaxCtrl.dispose();
    _safeAfrMidCtrl.dispose();
    _safeAfrWotCtrl.dispose();
    _revSoftCtrl.dispose();
    _revHardCtrl.dispose();
    _speedLimitCtrl.dispose();
    _maxRevRaiseCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Require acknowledgment phrase
    final acknowledged = await _showAcknowledgmentDialog();
    if (!acknowledged) return;

    setState(() => _isSaving = true);
    try {
      final updated = widget.model.copyWith(
        ecuType: _ecuTypeCtrl.text.trim(),
        flashTool: _flashToolCtrl.text.trim(),
        safeAfrMin: double.tryParse(_safeAfrMinCtrl.text) ?? widget.model.safeAfrMin,
        safeAfrMax: double.tryParse(_safeAfrMaxCtrl.text) ?? widget.model.safeAfrMax,
        safeAfrMid: double.tryParse(_safeAfrMidCtrl.text) ?? widget.model.safeAfrMid,
        safeAfrWot: double.tryParse(_safeAfrWotCtrl.text) ?? widget.model.safeAfrWot,
        stockRevLimitSoft:
            int.tryParse(_revSoftCtrl.text) ?? widget.model.stockRevLimitSoft,
        stockRevLimitHard:
            int.tryParse(_revHardCtrl.text) ?? widget.model.stockRevLimitHard,
        stockSpeedLimit:
            int.tryParse(_speedLimitCtrl.text) ?? widget.model.stockSpeedLimit,
        maxSafeRevRaise:
            int.tryParse(_maxRevRaiseCtrl.text) ?? widget.model.maxSafeRevRaise,
      );
      await DbHelper.updateMotorcycle(updated);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _showAcknowledgmentDialog() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: AppColors.danger, size: 20),
          SizedBox(width: 8),
          Text('Kumpirmahin ang Pagbabago'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Ang pagbabago ng mga safety parameters ay maaaring magdulot ng pinsala '
            'sa motorsiklo o sasakay. Tiyakin na alam mo ang ginagawa mo.\n\n'
            'I-type ang:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'NAIINTINDIHAN KO ANG PANGANIB',
              style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'I-type ang phrase dito...',
              isDense: true,
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kanselahin',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final match = ctrl.text.trim().toUpperCase() ==
                  'NAIINTINDIHAN KO ANG PANGANIB';
              Navigator.pop(ctx, match);
            },
            child: const Text('I-confirm'),
          ),
        ],
      ),
    );
    if (confirmed == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mali ang phrase. Hindi na-save ang mga pagbabago.'),
        ),
      );
    }
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final m = widget.model;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Text(
              '${m.brand} ${m.model} ${m.variant}',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.pop(context, false),
          ),
        ]),

        // Safety floor read-only
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.lock, color: AppColors.danger, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Max Timing Advance: +${m.maxTimingAdvance}° '
                '(Compression ${m.compressionRatio}:1 — HINDI MABABAGO)',
                style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        Flexible(
          child: SingleChildScrollView(
            child: Column(children: [
              _AdminField(ctrl: _ecuTypeCtrl, label: 'ECU Type'),
              _AdminField(ctrl: _flashToolCtrl, label: 'Flash Tool'),
              const _SectionDivider(label: 'AFR Safe Range'),
              Row(children: [
                Expanded(child: _AdminField(
                    ctrl: _safeAfrMinCtrl, label: 'AFR Min',
                    keyboard: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _AdminField(
                    ctrl: _safeAfrMaxCtrl, label: 'AFR Max',
                    keyboard: TextInputType.number)),
              ]),
              Row(children: [
                Expanded(child: _AdminField(
                    ctrl: _safeAfrMidCtrl, label: 'AFR Mid Target',
                    keyboard: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _AdminField(
                    ctrl: _safeAfrWotCtrl, label: 'AFR WOT Target',
                    keyboard: TextInputType.number)),
              ]),
              const _SectionDivider(label: 'Rev Limits (RPM)'),
              Row(children: [
                Expanded(child: _AdminField(
                    ctrl: _revSoftCtrl, label: 'Rev Limit Soft',
                    keyboard: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _AdminField(
                    ctrl: _revHardCtrl, label: 'Rev Limit Hard',
                    keyboard: TextInputType.number)),
              ]),
              Row(children: [
                Expanded(child: _AdminField(
                    ctrl: _maxRevRaiseCtrl, label: 'Max Rev Raise (abs.)',
                    keyboard: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _AdminField(
                    ctrl: _speedLimitCtrl, label: 'Speed Limit (km/h)',
                    keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('I-save ang mga Pagbabago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  onPressed: _isSaving ? null : _save,
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _AdminField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType keyboard;
  const _AdminField({
    required this.ctrl,
    required this.label,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );
}

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppColors.cardBorder, height: 1)),
        ]),
      );
}
