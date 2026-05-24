import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/database/db_helper.dart';
import '../../core/safety/safety_score.dart';
import '../../models/motorcycle_model.dart';
import '../../models/session_log.dart';
import '../../services/bluetooth_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<SessionLog> _recentSessions = [];
  MotorcycleModel? _selectedModel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modelId = prefs.getString('selected_model_id');
      final sessions = await DbHelper.getRecentSessions(5);
      final model = modelId != null
          ? await DbHelper.getMotorcycleById(modelId)
          : null;
      if (mounted) {
        setState(() {
          _recentSessions = sessions;
          _selectedModel = model;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _todaySessionCount {
    final today = DateTime.now();
    return _recentSessions.where((s) {
      return s.timestamp.year == today.year &&
          s.timestamp.month == today.month &&
          s.timestamp.day == today.day;
    }).length;
  }

  String get _lastModelName {
    if (_recentSessions.isEmpty) return '—';
    final last = _recentSessions.first;
    return '${last.motorcycleBrand} ${last.motorcycleModel}';
  }

  int get _latestScore {
    if (_recentSessions.isEmpty) return 0;
    return _recentSessions.first.preRemapSafetyScore;
  }

  @override
  Widget build(BuildContext context) {
    final btStatus = ref.watch(bluetoothStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.appName,
          style: GoogleFonts.rajdhani(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/admin'),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SelectedModelCard(
                      model: _selectedModel,
                      onTap: () async {
                        await Navigator.pushNamed(context, '/model-selector');
                        _loadData();
                      },
                    ),
                    const SizedBox(height: 16),
                    _QuickStatsRow(
                      todaySessions: _todaySessionCount,
                      lastModelName: _lastModelName,
                      score: _latestScore,
                    ),
                    const SizedBox(height: 16),
                    const _QuickActionGrid(),
                    const SizedBox(height: 16),
                    _OBDStatusBanner(btStatus: btStatus),
                    const SizedBox(height: 16),
                    _RecentSessionsList(sessions: _recentSessions),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selected Model Card
// ---------------------------------------------------------------------------

class _SelectedModelCard extends StatelessWidget {
  final MotorcycleModel? model;
  final VoidCallback onTap;

  const _SelectedModelCard({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasModel = model != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasModel ? AppColors.primary : AppColors.cardBorder,
            width: hasModel ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.two_wheeler, color: AppColors.primary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: hasModel
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${model!.brand} ${model!.model} (${model!.yearFrom})',
                          style: GoogleFonts.rajdhani(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${model!.ecuType} • ${model!.displacement}cc',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Piliin ang motorsiklo',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Stats Row
// ---------------------------------------------------------------------------

class _QuickStatsRow extends StatelessWidget {
  final int todaySessions;
  final String lastModelName;
  final int score;

  const _QuickStatsRow({
    required this.todaySessions,
    required this.lastModelName,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final icon = SafetyScore.iconFromScore(score);
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Ngayon',
            value: '$todaySessions sessions',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Huling',
            value: lastModelName,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Score',
            value: '$score/100 $icon',
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Action Grid
// ---------------------------------------------------------------------------

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid();

  @override
  Widget build(BuildContext context) {
    const actions = [
      _QuickAction(icon: Icons.search, label: 'Mag-scan', route: '/pre-remap'),
      _QuickAction(icon: Icons.tune, label: 'Tune Profile', route: '/tune-profiles'),
      _QuickAction(icon: Icons.sensors, label: 'Live Monitor', route: '/live-monitor'),
      _QuickAction(icon: Icons.history, label: 'History', route: '/sessions'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: actions
          .map((a) => _QuickActionCard(action: a))
          .toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String route;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, action.route),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: AppColors.primary, size: 26),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OBD Status Banner
// ---------------------------------------------------------------------------

class _OBDStatusBanner extends ConsumerWidget {
  final AsyncValue<AdapterConnectionStatus> btStatus;

  const _OBDStatusBanner({required this.btStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = btStatus.valueOrNull ?? AdapterConnectionStatus.disconnected;
    final connected = status == AdapterConnectionStatus.connected;

    return GestureDetector(
      onTap: () => _showBTScanDialog(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: connected ? AppColors.safe : AppColors.cardBorder,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.bluetooth,
              color: connected ? AppColors.safe : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                connected
                    ? 'OBD: Nakakonekta'
                    : 'OBD: Disconnected — I-tap para kumonekta',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: connected ? AppColors.safe : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBTScanDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _BTScanDialog(ref: ref),
    );
  }
}

class _BTScanDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _BTScanDialog({required this.ref});

  @override
  ConsumerState<_BTScanDialog> createState() => _BTScanDialogState();
}

class _BTScanDialogState extends ConsumerState<_BTScanDialog> {
  List<BluetoothDevice> _devices = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final service = ref.read(bluetoothServiceProvider);
    final devices = await service.scanForOBDAdapters();
    if (mounted) {
      setState(() {
        _devices = devices;
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        AppStrings.obdSearching,
        style: GoogleFonts.rajdhani(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      content: _scanning
          ? const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : _devices.isEmpty
              ? Text(
                  AppStrings.obdPairFirst,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.cardBorder, height: 1),
                    itemBuilder: (_, i) {
                      final device = _devices[i];
                      return ListTile(
                        leading: const Icon(Icons.bluetooth, color: AppColors.primary),
                        title: Text(
                          device.name ?? device.address,
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          device.address,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          final service = ref.read(bluetoothServiceProvider);
                          await service.connectToDevice(device);
                        },
                      );
                    },
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.buttonCancel),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Sessions List
// ---------------------------------------------------------------------------

class _RecentSessionsList extends StatelessWidget {
  final List<SessionLog> sessions;

  const _RecentSessionsList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.sessionsTitle,
          style: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Walang sessions pa',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          ...sessions.map((s) => _SessionCard(session: s)),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionLog session;

  const _SessionCard({required this.session});

  String get _resultIcon {
    return switch (session.result) {
      SessionResult.success => '✅',
      SessionResult.issues => '⚠️',
      SessionResult.rollbackNeeded => '❌',
    };
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(
            _resultIcon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.motorcycleBrand} ${session.motorcycleModel} ${session.motorcycleVariant}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(session.timestamp)}${session.profileName != null ? ' • ${session.profileName}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
