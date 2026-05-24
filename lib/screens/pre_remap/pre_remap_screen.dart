import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/safety/safety_validator.dart';
import '../../models/motorcycle_model.dart';
import '../../widgets/safety_score_widget.dart';
import '../../widgets/warning_dialog.dart';
import 'fault_code_screen.dart';

class PreRemapScreen extends ConsumerStatefulWidget {
  const PreRemapScreen({super.key});

  @override
  ConsumerState<PreRemapScreen> createState() => _PreRemapScreenState();
}

class _PreRemapScreenState extends ConsumerState<PreRemapScreen> {
  MotorcycleModel? _model;
  bool _isLoading = true;

  // Section 1: fault code scan
  int _faultCodeCount = 0;
  bool _scanDone = false;

  // Section 2: engine warm-up (-15 penalty if false)
  bool _engineWarmedUp = false;

  // Section 3: physical checklist — 7 items (-10 each if unchecked)
  final List<bool> _checklist = List<bool>.filled(7, false, growable: true);

  // Section 4: backup confirmation (HARD BLOCK if false)
  bool _backupConfirmed = false;

  static const _checklistLabels = [
    'Air filter — malinis at hindi blocked',
    'Spark plug — kondisyon at tamang gap',
    'Fuel lines at pump — walang leaks o kinks',
    'Baterya — 12.4V+ at fully charged',
    'Exhaust joints — lahat sealed, walang leaks',
    'Throttle cable — smooth, walang sticking',
    'Motorsiklo — ligtas na nakapark at stable',
  ];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('selected_model_id');
    final model = id != null ? await DbHelper.getMotorcycleById(id) : null;
    if (mounted) setState(() { _model = model; _isLoading = false; });
  }

  SafetyValidationResult get _result => SafetyValidator.calculatePreRemapScore(
        activeFaultCodeCount: _faultCodeCount,
        engineWarmedUp: _engineWarmedUp,
        uncheckedChecklistItems: _checklist.where((v) => !v).length,
        backupConfirmed: _backupConfirmed,
      );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_model == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pre-Remap Checklist')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Walang napiling motorsiklo.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamedAndRemoveUntil(context, '/model-selector', (_) => false),
              child: const Text('Pumili ng Motorsiklo'),
            ),
          ]),
        ),
      );
    }

    final result = _result;
    final canProceed = result.level != SafetyLevel.hardLock &&
        !result.backupRequired &&
        _scanDone;

    return Scaffold(
      appBar: AppBar(title: const Text('Pre-Remap Checklist')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Safety score
          _ScoreCard(result: result),
          const SizedBox(height: 16),

          // 1. Fault code scan
          _SectionHeader(title: '1. Fault Code Scan', icon: Icons.search),
          const SizedBox(height: 8),
          _buildFaultSection(),
          const SizedBox(height: 16),

          // 2. Engine warm-up
          _SectionHeader(title: '2. Engine Warm-Up', icon: Icons.thermostat_outlined),
          const SizedBox(height: 8),
          _buildWarmUpRow(),
          const SizedBox(height: 16),

          // 3. Physical checklist
          _SectionHeader(title: '3. Physical Checks', icon: Icons.checklist),
          const SizedBox(height: 8),
          ...List.generate(7, _buildCheckItem),
          const SizedBox(height: 16),

          // 4. ECU backup (HARD BLOCK)
          _SectionHeader(title: '4. ECU Backup (REQUIRED)', icon: Icons.backup),
          const SizedBox(height: 8),
          _buildBackupSection(),
          const SizedBox(height: 16),

          // Active warnings
          if (result.warnings.isNotEmpty) ...[
            ...result.warnings.map(_buildWarningBanner),
            const SizedBox(height: 8),
          ],

          // Proceed button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Pumunta sa Tune Profiles'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canProceed ? AppColors.primary : AppColors.cardBorder,
                foregroundColor: canProceed
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: canProceed
                  ? () async {
                      if (_result.level == SafetyLevel.warning) {
                        final ok = await showSafetyResultDialog(context, _result);
                        if (!ok || !mounted) return;
                      }
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('pre_remap_score', _result.score);
                      if (mounted) Navigator.pushNamed(context, '/tune-profiles');
                    }
                  : null,
            ),
          ),

          if (!_scanDone)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'I-scan muna ang fault codes bago magpatuloy.',
                style: TextStyle(color: AppColors.warning, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          if (!_backupConfirmed)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Kailangan ng ECU backup. HARD BLOCK — hindi maaaring laktawan.',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  Widget _buildFaultSection() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _scanDone
                ? (_faultCodeCount == 0 ? AppColors.safe : AppColors.warning)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(children: [
          Row(children: [
            Icon(
              _scanDone
                  ? (_faultCodeCount == 0 ? Icons.check_circle : Icons.warning_amber)
                  : Icons.pending_outlined,
              color: _scanDone
                  ? (_faultCodeCount == 0 ? AppColors.safe : AppColors.warning)
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _scanDone
                    ? (_faultCodeCount == 0
                        ? 'Walang fault codes — maayos ang ECU!'
                        : '$_faultCodeCount fault code(s) ang natagpuan.')
                    : 'Hindi pa na-scan. I-connect ang OBD adapter.',
                style: TextStyle(
                  color: _scanDone
                      ? (_faultCodeCount == 0
                          ? AppColors.safe
                          : AppColors.warning)
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label:
                Text(_scanDone ? 'I-rescan' : 'I-scan ang Fault Codes'),
            onPressed: _openFaultCodeScreen,
          ),
        ]),
      );

  Widget _buildWarmUpRow() => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _engineWarmedUp ? AppColors.safe : AppColors.warning,
            width: _engineWarmedUp ? 1 : 1.5,
          ),
        ),
        child: CheckboxListTile(
          title: const Text(
            'Nainit na ang engine (≥70°C)',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Tumakbo ng ≥5 minuto. Penalty kung hindi: −15 puntos.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          secondary: Icon(
            Icons.thermostat,
            color: _engineWarmedUp ? AppColors.safe : AppColors.warning,
          ),
          value: _engineWarmedUp,
          onChanged: (v) => setState(() => _engineWarmedUp = v!),
        ),
      );

  Widget _buildCheckItem(int index) {
    final checked = _checklist[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: CheckboxListTile(
        title: Text(
          _checklistLabels[index],
          style: TextStyle(
            color: checked ? AppColors.textSecondary : AppColors.textPrimary,
            fontSize: 13,
            decoration: checked ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.textSecondary,
          ),
        ),
        value: checked,
        onChanged: (v) => setState(() => _checklist[index] = v!),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
      ),
    );
  }

  Widget _buildBackupSection() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _backupConfirmed
              ? AppColors.safe.withValues(alpha: 0.07)
              : AppColors.danger.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _backupConfirmed ? AppColors.safe : AppColors.danger,
            width: _backupConfirmed ? 1 : 2,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.backup,
                color: _backupConfirmed ? AppColors.safe : AppColors.danger),
            const SizedBox(width: 8),
            Text(
              _backupConfirmed
                  ? 'ECU Backup — Kumpleto'
                  : 'ECU Backup — KINAKAILANGAN',
              style: TextStyle(
                color: _backupConfirmed ? AppColors.safe : AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Bago ang anumang remap, i-backup muna ang orihinal na ECU map '
            'gamit ang iyong laptop flashing tool. Safety net ito kung magkamali.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          CheckboxListTile(
            title: const Text(
              'Nakuha na ang ECU backup sa laptop flashing tool',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            value: _backupConfirmed,
            onChanged: (v) => setState(() => _backupConfirmed = v!),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        ]),
      );

  Widget _buildWarningBanner(ValidationWarning w) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: w.isBlocking
              ? AppColors.danger.withValues(alpha: 0.1)
              : AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: w.isBlocking ? AppColors.danger : AppColors.warning),
        ),
        child: Row(children: [
          Icon(
            w.isBlocking ? Icons.block : Icons.warning_amber,
            color: w.isBlocking ? AppColors.danger : AppColors.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              w.message,
              style: TextStyle(
                  color: w.isBlocking ? AppColors.danger : AppColors.warning,
                  fontSize: 12),
            ),
          ),
        ]),
      );

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _openFaultCodeScreen() async {
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
          builder: (_) => FaultCodeScreen(modelId: _model!.id)),
    );
    if (count != null && mounted) {
      setState(() {
        _faultCodeCount = count;
        _scanDone = true;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Score card widget
// ---------------------------------------------------------------------------

class _ScoreCard extends StatelessWidget {
  final SafetyValidationResult result;
  const _ScoreCard({required this.result});

  Color get _levelColor => switch (result.level) {
    SafetyLevel.approved => AppColors.safe,
    SafetyLevel.warning => AppColors.warning,
    SafetyLevel.hardLock => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final subtext = switch (result.level) {
      SafetyLevel.approved => 'Handa ang motorsiklo para sa remap.',
      SafetyLevel.warning => 'May mga isyu — magpatuloy nang maingat.',
      SafetyLevel.hardLock => 'Hindi maaaring mag-remap — ayusin muna.',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _levelColor, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Pre-Remap Score',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 8),
        SafetyScoreWidget(
          score: result.score,
          level: result.level,
          subtitle: subtext,
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header widget
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
      ]);
}
