import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../models/session_log.dart';

enum _SessionFilter { all, success, issues, rollback }

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<SessionLog> _sessions = [];
  bool _isLoading = true;
  _SessionFilter _filter = _SessionFilter.all;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final sessions = await DbHelper.getAllSessions();
    if (mounted) setState(() { _sessions = sessions; _isLoading = false; });
  }

  List<SessionLog> get _filtered => _sessions.where(_matchesFilter).toList();

  bool _matchesFilter(SessionLog s) => switch (_filter) {
        _SessionFilter.all => true,
        _SessionFilter.success => s.result == SessionResult.success,
        _SessionFilter.issues => s.result == SessionResult.issues,
        _SessionFilter.rollback => s.result == SessionResult.rollbackNeeded,
      };

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasaysayan ng Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: Column(children: [
        _buildFilterRow(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildFilterRow() => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FilterChip(
              label: 'Lahat',
              active: _filter == _SessionFilter.all,
              color: AppColors.primary,
              onTap: () => setState(() => _filter = _SessionFilter.all),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '✅ Matagumpay',
              active: _filter == _SessionFilter.success,
              color: AppColors.safe,
              onTap: () => setState(() => _filter = _SessionFilter.success),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '⚠️ May Isyu',
              active: _filter == _SessionFilter.issues,
              color: AppColors.warning,
              onTap: () => setState(() => _filter = _SessionFilter.issues),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '❌ Rollback',
              active: _filter == _SessionFilter.rollback,
              color: AppColors.danger,
              onTap: () => setState(() => _filter = _SessionFilter.rollback),
            ),
          ]),
        ),
      );

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history_outlined, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Walang sessions pa.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Magsimula ng Pre-Remap'),
            onPressed: () =>
                Navigator.pushNamedAndRemoveUntil(context, '/pre-remap', (_) => false),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (_, i) => _SessionCard(
          session: list[i],
          onTap: () => _showDetail(list[i]),
        ),
      ),
    );
  }

  void _showDetail(SessionLog s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppColors.cardBorder),
      ),
      builder: (_) => _SessionDetailSheet(session: s),
    );
  }
}

// ---------------------------------------------------------------------------
// Session card
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  final SessionLog session;
  final VoidCallback onTap;
  const _SessionCard({required this.session, required this.onTap});

  static final _fmt = DateFormat('MMM d, yyyy HH:mm');

  String get _resultIcon => switch (session.result) {
        SessionResult.success => '✅',
        SessionResult.issues => '⚠️',
        SessionResult.rollbackNeeded => '❌',
      };

  Color get _resultColor => switch (session.result) {
        SessionResult.success => AppColors.safe,
        SessionResult.issues => AppColors.warning,
        SessionResult.rollbackNeeded => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(children: [
          Text(_resultIcon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${session.motorcycleBrand} ${session.motorcycleModel} ${session.motorcycleVariant}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                _fmt.format(session.timestamp),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              if (session.profileName != null)
                Text(
                  session.profileName!,
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 11),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '${session.preRemapSafetyScore}/100',
              style: TextStyle(
                  color: _resultColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
            if (session.requiresFollowUp)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Follow-up',
                    style: TextStyle(color: AppColors.warning, fontSize: 9)),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail bottom sheet
// ---------------------------------------------------------------------------

class _SessionDetailSheet extends StatelessWidget {
  final SessionLog session;
  const _SessionDetailSheet({required this.session});

  static final _fmt = DateFormat('MMM d, yyyy HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.cardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Text(
                '${session.motorcycleBrand} ${session.motorcycleModel}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(color: AppColors.cardBorder, height: 1),
        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              _DetailRow('Motorsiklo',
                  '${session.motorcycleBrand} ${session.motorcycleModel} ${session.motorcycleVariant} (${session.motorcycleYear})'),
              _DetailRow('Petsa', _fmt.format(session.timestamp)),
              _DetailRow('Resulta', switch (session.result) {
                SessionResult.success => '✅ Matagumpay',
                SessionResult.issues => '⚠️ May Isyu',
                SessionResult.rollbackNeeded => '❌ Rollback Kinakailangan',
              }),
              _DetailRow('Pre-Remap Score',
                  '${session.preRemapSafetyScore}/100'),
              if (session.tuneSafetyScore != null)
                _DetailRow('Tune Safety Score',
                    '${session.tuneSafetyScore}/100'),
              if (session.profileName != null)
                _DetailRow('Tune Profile', session.profileName!),
              if (session.clientName != null)
                _DetailRow('Kliyente', session.clientName!),
              if (session.clientPlate != null)
                _DetailRow('Plate', session.clientPlate!),
              if (session.warningsTriggered.isNotEmpty)
                _DetailRow('Mga Babala',
                    session.warningsTriggered.join('\n')),
              if (session.technicianNotes != null &&
                  session.technicianNotes!.isNotEmpty)
                _DetailRow('Tala ng Mekaniko', session.technicianNotes!),
              _DetailRow(
                  'Follow-up Kinakailangan',
                  session.requiresFollowUp ? 'Oo' : 'Hindi'),
            ],
          ),
        ),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 6),
          const Divider(color: AppColors.cardBorder, height: 1),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : AppColors.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? color : AppColors.cardBorder, width: active ? 1.5 : 1),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: active ? color : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal),
          ),
        ),
      );
}
