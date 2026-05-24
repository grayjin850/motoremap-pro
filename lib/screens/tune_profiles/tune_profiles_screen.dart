import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/safety/safety_validator.dart';
import '../../models/motorcycle_model.dart';
import '../../models/tune_profile.dart';
import '../../widgets/safety_score_widget.dart';
import '../../widgets/warning_dialog.dart';

class TuneProfilesScreen extends ConsumerStatefulWidget {
  const TuneProfilesScreen({super.key});

  @override
  ConsumerState<TuneProfilesScreen> createState() =>
      _TuneProfilesScreenState();
}

class _TuneProfilesScreenState extends ConsumerState<TuneProfilesScreen> {
  MotorcycleModel? _model;
  List<TuneProfile> _profiles = [];
  bool _isLoading = true;
  int _pageIndex = 0;
  bool _backupConfirmed = false;
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final modelId = prefs.getString('selected_model_id');
    if (modelId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final model = await DbHelper.getMotorcycleById(modelId);
    final profiles = model != null
        ? await DbHelper.getProfilesByModelId(modelId)
        : <TuneProfile>[];
    if (mounted) {
      setState(() {
        _model = model;
        _profiles = profiles;
        _isLoading = false;
      });
    }
  }

  Future<void> _setSelectedProfile(TuneProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_profile_id', p.id);
  }

  Future<void> _navigate(String route) async {
    if (!_backupConfirmed) return;
    final profile = _profiles[_pageIndex];
    final result = SafetyValidator.calculateTuneSafetyScore(
      model: _model!,
      profile: profile,
      backupConfirmed: _backupConfirmed,
    );

    if (result.level == SafetyLevel.hardLock) {
      await showSafetyResultDialog(context, result);
      return;
    }

    if (SafetyValidator.requiresVvaWarning(model: _model!, profile: profile)) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.warning, color: AppColors.vvaZone),
            SizedBox(width: 8),
            Text('VVA Zone Warning'),
          ]),
          content: Text(
            '${_model!.brand} ${_model!.model} ay may VVA (Variable Valve Actuation) '
            'na nag-a-activate sa ~${_model!.vvaTransitionRpm} RPM.\n\n'
            'Ang timing advance na ${profile.timingAdvanceDeg}° ay nangangailangan '
            'ng espesyal na atensyon sa 5,800–6,200 RPM zone. '
            'Mag-monitor nang mabuti para sa knock o abnormal na vibration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bumalik',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.vvaZone),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Naintindihan, Magpatuloy'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    await _setSelectedProfile(profile);
    if (mounted) Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_model == null || _profiles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tune Profiles')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Walang tune profiles para sa motorsiklong ito.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bumalik'),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Tune Profiles — ${_model!.brand} ${_model!.model}'),
      ),
      body: Column(children: [
        // Page dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_profiles.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _pageIndex == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _pageIndex == i
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
          ),
        ),

        // Profile card pager
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemCount: _profiles.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ProfileCard(
                profile: _profiles[i],
                model: _model!,
                isActive: i == _pageIndex,
              ),
            ),
          ),
        ),

        // Backup confirmation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: _backupConfirmed
                  ? AppColors.safe.withValues(alpha: 0.08)
                  : AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _backupConfirmed ? AppColors.safe : AppColors.danger),
            ),
            child: CheckboxListTile(
              title: const Text(
                'Nakunan na ng ECU backup bago itong remap',
                style:
                    TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
              value: _backupConfirmed,
              onChanged: (v) => setState(() => _backupConfirmed = v!),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12),
              dense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Map navigation buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Fuel Map'),
                onPressed: _backupConfirmed
                    ? () => _navigate('/fuel-map')
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flash_on),
                label: const Text('Ignition Map'),
                onPressed: _backupConfirmed
                    ? () => _navigate('/ignition-map')
                    : null,
              ),
            ),
          ]),
        ),
        const SafeArea(child: SizedBox(height: 16)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile card
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  final TuneProfile profile;
  final MotorcycleModel model;
  final bool isActive;

  const _ProfileCard({
    required this.profile,
    required this.model,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final result = SafetyValidator.calculateTuneSafetyScore(
      model: model,
      profile: profile,
      backupConfirmed: true,
    );
    final scoreColor = switch (result.level) {
      SafetyLevel.approved => AppColors.safe,
      SafetyLevel.warning => AppColors.warning,
      SafetyLevel.hardLock => AppColors.danger,
    };
    final scoreLabel = switch (result.level) {
      SafetyLevel.approved => 'LIGTAS',
      SafetyLevel.warning => 'BABALA',
      SafetyLevel.hardLock => 'BLOCKED',
    };
    // scoreColor/scoreLabel kept for vvaWarning chip; ring replaced by SafetyScoreRing
    final typeIcon = switch (profile.type) {
      ProfileType.topSpeed => Icons.speed,
      ProfileType.cityResponse => Icons.location_city,
      ProfileType.handling => Icons.turn_slight_right,
      ProfileType.balanced => Icons.balance,
      ProfileType.eco => Icons.eco,
    };
    final vvaWarning =
        SafetyValidator.requiresVvaWarning(model: model, profile: profile);
    final timingUnsafe = profile.timingAdvanceDeg > model.maxTimingAdvance;

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.cardBorder,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.panel,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.nameTaglish,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text(
                        profile.descriptionTaglish,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score row
                  Row(children: [
                    SafetyScoreRing(score: result.score, level: result.level, size: 56),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tune Safety Score',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                          Text(scoreLabel,
                              style: TextStyle(
                                  color: scoreColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18)),
                        ]),
                    if (vvaWarning) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.vvaZone.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.vvaZone),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning,
                                  color: AppColors.vvaZone, size: 13),
                              SizedBox(width: 4),
                              Text('VVA',
                                  style: TextStyle(
                                      color: AppColors.vvaZone,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 14),
                  const Divider(color: AppColors.cardBorder),
                  const SizedBox(height: 10),

                  // Tune parameters
                  Row(children: [
                    _StatBox(
                        label: 'AFR Mid',
                        value: profile.afrTargetMid.toStringAsFixed(1)),
                    const SizedBox(width: 8),
                    _StatBox(
                        label: 'AFR WOT',
                        value: profile.afrTargetWot.toStringAsFixed(1)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _StatBox(
                      label: 'Timing Advance',
                      value: '+${profile.timingAdvanceDeg}°',
                      valueColor: timingUnsafe
                          ? AppColors.danger
                          : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'Rev Raise',
                      value: profile.revLimitRaise == 0
                          ? 'Stock'
                          : '+${profile.revLimitRaise} RPM',
                    ),
                  ]),

                  if (profile.removeSpeedLimiter) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                AppColors.warning.withValues(alpha: 0.5)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.speed, color: AppColors.warning, size: 14),
                        SizedBox(width: 6),
                        Text('Speed limiter removed',
                            style: TextStyle(
                                color: AppColors.warning, fontSize: 12)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Text(profile.expectedBenefits,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      const Icon(Icons.local_gas_station,
                          color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(profile.fuelConsumptionNote,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ),
                    ]),
                  ),

                  // Safety warnings (exclude BACKUP warning here)
                  if (result.warnings
                      .where((w) => !w.code.contains('BACKUP'))
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...result.warnings
                        .where((w) => !w.code.contains('BACKUP'))
                        .map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                Icon(
                                    w.isBlocking
                                        ? Icons.block
                                        : Icons.info_outline,
                                    color: w.isBlocking
                                        ? AppColors.danger
                                        : AppColors.warning,
                                    size: 13),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(w.message,
                                      style: TextStyle(
                                          color: w.isBlocking
                                              ? AppColors.danger
                                              : AppColors.warning,
                                          fontSize: 11)),
                                ),
                              ]),
                            )),
                  ],
                ]),
          ),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatBox({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
        ),
      );
}
