import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';

class _ServiceInterval {
  final String name;
  final String nameTaglish;
  final int kmInterval;
  final int monthInterval;
  final IconData icon;

  const _ServiceInterval({
    required this.name,
    required this.nameTaglish,
    required this.kmInterval,
    required this.monthInterval,
    required this.icon,
  });
}

const _intervals = [
  _ServiceInterval(
    name: 'Oil Change',
    nameTaglish: 'Palitan ng Langis',
    kmInterval: 1000,
    monthInterval: 3,
    icon: Icons.opacity,
  ),
  _ServiceInterval(
    name: 'Air Filter',
    nameTaglish: 'Air Filter — Linis o Palitan',
    kmInterval: 5000,
    monthInterval: 6,
    icon: Icons.air,
  ),
  _ServiceInterval(
    name: 'Spark Plug',
    nameTaglish: 'Spark Plug — Palitan',
    kmInterval: 10000,
    monthInterval: 12,
    icon: Icons.flash_on_outlined,
  ),
  _ServiceInterval(
    name: 'Chain Lube',
    nameTaglish: 'Chain Lubrication',
    kmInterval: 500,
    monthInterval: 1,
    icon: Icons.link,
  ),
  _ServiceInterval(
    name: 'Brake Pads',
    nameTaglish: 'Brake Pads — I-inspect',
    kmInterval: 5000,
    monthInterval: 6,
    icon: Icons.disc_full,
  ),
  _ServiceInterval(
    name: 'Coolant Flush',
    nameTaglish: 'Coolant — Palitan',
    kmInterval: 20000,
    monthInterval: 24,
    icon: Icons.water_drop_outlined,
  ),
];

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  PermissionStatus _notifStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _notifStatus = status);
  }

  Future<void> _requestPermission() async {
    final status = await Permission.notification.request();
    if (mounted) setState(() => _notifStatus = status);
    if (status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications pinagana! '
              'Buksan ang app para i-trigger ang reminders.'),
        ),
      );
    } else if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notifications nakatanggi. Buksan ang Settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Reminders'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notification permission section
          _buildNotifBanner(),
          const SizedBox(height: 16),

          // Service intervals
          const Row(children: [
            Icon(Icons.build_outlined, color: AppColors.primary, size: 16),
            SizedBox(width: 8),
            Text('Mga Service Interval',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Narito ang mga inirerekomendang service interval para sa karaniwang motorsiklo. '
            'I-record ang bawat service sa Sessions para ma-track ang kasaysayan.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),

          ..._intervals.map((interval) => _IntervalCard(interval: interval)),

          const SizedBox(height: 16),

          // Tip card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Icon(Icons.lightbulb_outline,
                    color: AppColors.warning, size: 16),
                SizedBox(width: 8),
                Text('Tip para sa Mekaniko',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ]),
              SizedBox(height: 8),
              Text(
                'Laging i-check ang coolant at baterya bago ang bawat remap. '
                'Mababang coolant o mahina na baterya ay maaaring magdulot ng maling OBD readings '
                'at mapanganib na tuning conditions.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNotifBanner() {
    final granted = _notifStatus.isGranted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: granted
            ? AppColors.safe.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted ? AppColors.safe : AppColors.warning,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            granted ? Icons.notifications_active : Icons.notifications_off_outlined,
            color: granted ? AppColors.safe : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            granted ? 'Notifications Pinagana' : 'Notifications Hindi Pa Pinagana',
            style: TextStyle(
                color: granted ? AppColors.safe : AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          granted
              ? 'Makakatanggap ka ng reminders kapag may due na service '
                'sa susunod na update ng app.'
              : 'Payagan ang notifications para makatanggap ng maintenance reminders. '
                'Kapaki-pakinabang para hindi malimutan ang service dates ng mga kliyente.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (!granted) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.notifications_outlined, size: 16),
              label: const Text('Payagan ang Notifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: _requestPermission,
            ),
          ),
        ],
      ]),
    );
  }
}

class _IntervalCard extends StatelessWidget {
  final _ServiceInterval interval;
  const _IntervalCard({required this.interval});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(interval.icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(interval.nameTaglish,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              '${_formatKm(interval.kmInterval)} km  •  bawat ${interval.monthInterval} buwan',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ]),
        ),
      ]),
    );
  }

  String _formatKm(int km) {
    if (km >= 1000) return '${km ~/ 1000},000';
    return km.toString();
  }
}
