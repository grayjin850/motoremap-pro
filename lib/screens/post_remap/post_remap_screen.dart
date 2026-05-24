import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/safety/safety_validator.dart';
import '../../models/motorcycle_model.dart';
import '../../models/session_log.dart';
import '../../models/tune_profile.dart';
import '../../services/obd_service.dart';
import '../pre_remap/fault_code_screen.dart';

class PostRemapScreen extends ConsumerStatefulWidget {
  const PostRemapScreen({super.key});

  @override
  ConsumerState<PostRemapScreen> createState() => _PostRemapScreenState();
}

class _PostRemapScreenState extends ConsumerState<PostRemapScreen> {
  MotorcycleModel? _model;
  TuneProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  int _preRemapScore = 0;

  // Section A — fault code scan
  int? _postFaultCount;
  bool _scanDone = false;

  // Section B — cold start (5 items, +20 if all)
  final List<bool> _coldStart = List.filled(5, false, growable: true);
  static const _coldStartLabels = [
    'Motor nag-start nang maayos',
    'Idle stable, hindi nagta-tango',
    'Walang hunting o rough idle',
    'Walang unusual tunog o vibration',
    'Walang smoke mula sa exhaust',
  ];

  // Section C — warm-up monitor (+20 when ≥70°C)
  bool _warmUpReached = false;
  int? _currentCoolantC;

  // Section D — test ride (5 items, +30 if all)
  final List<bool> _testRide = List.filled(5, false, growable: true);
  static const _testRideLabels = [
    'Low RPM (1–3k) — smooth, walang stutter',
    'Mid RPM (3–6k) — walang flat spot',
    'High RPM (6k+) — walang knock o ping',
    'Speed limiter — nag-a-activate sa tamang speed',
    'Engine braking — smooth, walang surge',
  ];

  // Section E — save
  final _notesController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientPlateController = TextEditingController();
  SessionResult _sessionResult = SessionResult.success;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _clientNameController.dispose();
    _clientPlateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final modelId = prefs.getString('selected_model_id');
    final profileId = prefs.getString('selected_profile_id');
    _preRemapScore = prefs.getInt('pre_remap_score') ?? 0;

    final model = modelId != null ? await DbHelper.getMotorcycleById(modelId) : null;
    final profile = profileId != null ? await DbHelper.getProfileById(profileId) : null;

    if (mounted) {
      setState(() {
        _model = model;
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Scoring
  // ---------------------------------------------------------------------------

  int get _faultScore {
    if (!_scanDone || _postFaultCount == null) return 0;
    if (_postFaultCount! == 0) return 30;
    if (_postFaultCount! <= 2) return 15;
    return 0;
  }

  int get _coldStartScore => _coldStart.every((v) => v) ? 20 : 0;
  int get _warmUpScore => _warmUpReached ? 20 : 0;
  int get _testRideScore => _testRide.every((v) => v) ? 30 : 0;
  int get _totalScore => _faultScore + _coldStartScore + _warmUpScore + _testRideScore;

  SessionResult get _recommendedResult {
    final s = _totalScore;
    if (s >= 80) return SessionResult.success;
    if (s >= 60) return SessionResult.issues;
    return SessionResult.rollbackNeeded;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<OBDReading>>(obdReadingProvider, (_, next) {
      next.whenData((reading) {
        if (!mounted) return;
        final temp = reading.coolantTempC;
        if (temp != null) {
          if (!_warmUpReached && temp >= 70) {
            setState(() => _warmUpReached = true);
          }
          if (temp != _currentCoolantC) {
            setState(() => _currentCoolantC = temp);
          }
        }
      });
    });

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_model == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post-Remap Verification')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Walang napiling motorsiklo.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/model-selector', (_) => false),
              child: const Text('Pumili ng Motorsiklo'),
            ),
          ]),
        ),
      );
    }

    final scoreColor = _scoreColor(_totalScore);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post-Remap Verification'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_totalScore/100',
                style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildScoreCard(scoreColor),
          const SizedBox(height: 16),

          _SectionHeader(title: 'A. Post-Remap Fault Code Scan', icon: Icons.search),
          const SizedBox(height: 8),
          _buildFaultSection(),
          const SizedBox(height: 16),

          _SectionHeader(title: 'B. Cold Start Verification', icon: Icons.play_circle_outline),
          const SizedBox(height: 8),
          ...List.generate(5, _buildColdStartItem),
          const SizedBox(height: 16),

          _SectionHeader(title: 'C. Warm-Up Monitor', icon: Icons.thermostat_outlined),
          const SizedBox(height: 8),
          _buildWarmUpSection(),
          const SizedBox(height: 16),

          _SectionHeader(title: 'D. Test Ride Checklist', icon: Icons.two_wheeler),
          const SizedBox(height: 8),
          ...List.generate(5, _buildTestRideItem),
          const SizedBox(height: 16),

          _SectionHeader(title: 'E. Final Assessment & Save', icon: Icons.save_outlined),
          const SizedBox(height: 8),
          _buildFinalSection(scoreColor),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  Widget _buildScoreCard(Color scoreColor) {
    final label = _totalScore >= 80
        ? 'MATAGUMPAY'
        : _totalScore >= 60
            ? 'MAY ISYU'
            : 'ROLLBACK INIREREKOMENDA';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor, width: 2),
      ),
      child: Row(children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: _totalScore / 100,
              backgroundColor: AppColors.cardBorder,
              color: scoreColor,
              strokeWidth: 6,
            ),
            Text('$_totalScore',
                style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Post-Remap Score',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            Text(label,
                style: TextStyle(
                    color: scoreColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              _MiniScore(label: 'Fault', value: _faultScore, max: 30),
              _MiniScore(label: 'Start', value: _coldStartScore, max: 20),
              _MiniScore(label: 'Temp', value: _warmUpScore, max: 20),
              _MiniScore(label: 'Ride', value: _testRideScore, max: 30),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFaultSection() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !_scanDone
                ? AppColors.cardBorder
                : _postFaultCount == 0
                    ? AppColors.safe
                    : AppColors.warning,
          ),
        ),
        child: Column(children: [
          Row(children: [
            Icon(
              _scanDone
                  ? (_postFaultCount == 0 ? Icons.check_circle : Icons.warning_amber)
                  : Icons.pending_outlined,
              color: _scanDone
                  ? (_postFaultCount == 0 ? AppColors.safe : AppColors.warning)
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _scanDone
                    ? (_postFaultCount == 0
                        ? 'Walang bagong fault codes — malinis post-remap!'
                        : '$_postFaultCount fault code(s) pagkatapos ng remap.')
                    : 'I-scan ang ECU pagkatapos mag-flash.',
                style: TextStyle(
                  color: _scanDone
                      ? (_postFaultCount == 0 ? AppColors.safe : AppColors.warning)
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_scanDone ? 'I-rescan' : 'I-scan ang Fault Codes'),
                onPressed: _openFaultCodeScreen,
              ),
            ),
            if (_scanDone) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _faultScore == 30
                      ? AppColors.safe.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$_faultScore pts',
                  style: TextStyle(
                    color: _faultScore == 30 ? AppColors.safe : AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ]),
        ]),
      );

  Widget _buildColdStartItem(int index) {
    final checked = _coldStart[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: CheckboxListTile(
        title: Text(
          _coldStartLabels[index],
          style: TextStyle(
            color: checked ? AppColors.textSecondary : AppColors.textPrimary,
            fontSize: 13,
            decoration: checked ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.textSecondary,
          ),
        ),
        value: checked,
        onChanged: (v) => setState(() => _coldStart[index] = v!),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
      ),
    );
  }

  Widget _buildWarmUpSection() {
    final tempOpt = _currentCoolantC;
    final hasObd = tempOpt != null;
    final tempVal = tempOpt ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _warmUpReached
              ? AppColors.safe
              : hasObd
                  ? AppColors.warning
                  : AppColors.cardBorder,
          width: _warmUpReached ? 1 : 1.5,
        ),
      ),
      child: Column(children: [
        Row(children: [
          Icon(
            _warmUpReached ? Icons.check_circle : Icons.thermostat,
            color: _warmUpReached
                ? AppColors.safe
                : hasObd
                    ? AppColors.warning
                    : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _warmUpReached
                    ? 'Warm-up target reached — +20 pts!'
                    : 'Maghintay hanggang ≥70°C coolant temp.',
                style: TextStyle(
                  color: _warmUpReached ? AppColors.safe : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                hasObd
                    ? 'Live: ${tempVal}°C'
                    : 'OBD not connected — walang live data.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ]),
          ),
          if (hasObd)
            Text(
              '${tempVal}°C',
              style: TextStyle(
                color: _warmUpReached
                    ? AppColors.safe
                    : tempVal >= 70
                        ? AppColors.safe
                        : tempVal >= 50
                            ? AppColors.warning
                            : AppColors.textSecondary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (tempVal / 100).clamp(0.0, 1.0),
            backgroundColor: AppColors.cardBorder,
            color: _warmUpReached ? AppColors.safe : AppColors.warning,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('0°C', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          Text(
            'Target: 70°C',
            style: TextStyle(
                color: _warmUpReached ? AppColors.safe : AppColors.warning,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
          const Text('100°C', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ]),
        if (!hasObd) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('I-confirm nang Manu-mano (≥70°C)'),
              onPressed: () => setState(() => _warmUpReached = true),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildTestRideItem(int index) {
    final checked = _testRide[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: CheckboxListTile(
        title: Text(
          _testRideLabels[index],
          style: TextStyle(
            color: checked ? AppColors.textSecondary : AppColors.textPrimary,
            fontSize: 13,
            decoration: checked ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.textSecondary,
          ),
        ),
        value: checked,
        onChanged: (v) => setState(() => _testRide[index] = v!),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
      ),
    );
  }

  Widget _buildFinalSection(Color scoreColor) {
    final recommended = _recommendedResult;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Score summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scoreColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(
              _totalScore >= 80 ? Icons.thumb_up : Icons.info_outline,
              color: scoreColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _totalScore >= 80
                    ? 'Matagumpay ang remap! Kumpleto ang lahat ng checks.'
                    : _totalScore >= 60
                        ? 'May ilang isyu. Suriin ang mga hindi natanggap na check.'
                        : 'INIREREKOMENDA ANG ROLLBACK. Bumalik sa stock ECU map.',
                style: TextStyle(
                    color: scoreColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Session result selection
        const Text('Resulta ng Session',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...SessionResult.values.map((r) => RadioListTile<SessionResult>(
              title: Row(children: [
                Expanded(
                  child: Text(
                    switch (r) {
                      SessionResult.success => 'Matagumpay — OK ang lahat',
                      SessionResult.issues => 'May Isyu — kailangan ng follow-up',
                      SessionResult.rollbackNeeded => 'Rollback — bumalik sa stock map',
                    },
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                if (r == recommended) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Inirerekomenda',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              value: r,
              groupValue: _sessionResult,
              onChanged: (v) => setState(() => _sessionResult = v!),
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),

        const SizedBox(height: 12),
        const Divider(color: AppColors.cardBorder),
        const SizedBox(height: 12),

        // Optional client info
        const Text('Impormasyon ng Kliyente (opsyonal)',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _clientNameController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Pangalan ng Kliyente',
            hintText: 'e.g. Juan dela Cruz',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clientPlateController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Plate Number',
            hintText: 'e.g. ABC 1234',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        // Technician notes
        const Text('Mga Tala ng Mekaniko',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _notesController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Mga obserbasyon, isyu, o rekomendasyon...',
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: const Text('I-save ang Session at Tapusin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isSaving ? null : _saveSession,
          ),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.safe;
    if (score >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  Future<void> _openFaultCodeScreen() async {
    if (_model == null) return;
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => FaultCodeScreen(modelId: _model!.id)),
    );
    if (count != null && mounted) {
      setState(() {
        _postFaultCount = count;
        _scanDone = true;
      });
    }
  }

  Future<void> _saveSession() async {
    if (_model == null) return;
    setState(() => _isSaving = true);
    try {
      final tuneSafetyResult = _profile != null
          ? SafetyValidator.calculateTuneSafetyScore(
              model: _model!,
              profile: _profile!,
              backupConfirmed: true,
            )
          : null;

      final warnings =
          tuneSafetyResult?.warnings.map((w) => w.code).toList() ?? <String>[];

      final now = DateTime.now();
      final log = SessionLog(
        id: const Uuid().v4(),
        timestamp: now,
        motorcycleModelId: _model!.id,
        motorcycleBrand: _model!.brand,
        motorcycleModel: _model!.model,
        motorcycleVariant: _model!.variant,
        motorcycleYear: _model!.yearFrom,
        clientName: _clientNameController.text.trim().isEmpty
            ? null
            : _clientNameController.text.trim(),
        clientPlate: _clientPlateController.text.trim().isEmpty
            ? null
            : _clientPlateController.text.trim(),
        profileId: _profile?.id,
        profileName: _profile?.nameTaglish,
        preRemapSafetyScore: _preRemapScore,
        tuneSafetyScore: tuneSafetyResult?.score,
        warningsTriggered: warnings,
        obdDataSummary: null,
        technicianNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        result: _sessionResult,
        requiresFollowUp: _sessionResult != SessionResult.success,
        createdAt: now,
      );

      await DbHelper.insertSession(log);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/sessions', (_) => false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

// ---------------------------------------------------------------------------
// Mini score widget for the score card breakdown row
// ---------------------------------------------------------------------------

class _MiniScore extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  const _MiniScore({required this.label, required this.value, required this.max});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(
            '+$value',
            style: TextStyle(
                color: value == max ? AppColors.safe : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
          ),
        ]),
      );
}
