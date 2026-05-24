import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/afr_calculator.dart';
import '../../services/bluetooth_service.dart';
import '../../services/obd_service.dart';

class LiveMonitorScreen extends ConsumerStatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  ConsumerState<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends ConsumerState<LiveMonitorScreen> {
  final List<OBDReading> _log = [];
  bool _isRecording = false;
  bool _showLog = false;
  static const _maxLog = 200;

  String? _criticalAlert;
  String? _warningAlert;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Listen for new readings → update log and alerts
    ref.listen<AsyncValue<OBDReading>>(obdReadingProvider, (_, next) {
      next.whenData((reading) {
        if (!mounted) return;
        _checkAlerts(reading);
        if (_isRecording) {
          setState(() {
            _log.add(reading);
            if (_log.length > _maxLog) _log.removeAt(0);
          });
        }
      });
    });

    final obdAsync = ref.watch(obdReadingProvider);
    final btStatus = ref.watch(bluetoothStatusProvider).valueOrNull
        ?? BluetoothConnectionStatus.disconnected;
    final reading = obdAsync.when(
      data: (r) => r,
      loading: () => OBDReading.empty(),
      error: (_, __) => OBDReading.empty(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live OBD Monitor'),
        actions: [
          IconButton(
            icon: Icon(_showLog ? Icons.dashboard_outlined : Icons.table_rows_outlined),
            tooltip: _showLog ? 'Ipakita ang Gauges' : 'Ipakita ang Log',
            onPressed: () => setState(() => _showLog = !_showLog),
          ),
          IconButton(
            icon: Icon(
              _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
              color: _isRecording ? AppColors.danger : AppColors.textSecondary,
            ),
            tooltip: _isRecording ? 'Ihinto ang Recording' : 'Magsimula ng Recording',
            onPressed: () => setState(() => _isRecording = !_isRecording),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: _log.isNotEmpty ? _exportCsv : null,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(btStatus),
          if (_criticalAlert != null) _buildAlertBanner(_criticalAlert!, isCritical: true),
          if (_warningAlert != null) _buildAlertBanner(_warningAlert!, isCritical: false),
          if (!reading.hasAnyData) _buildNoDataBanner(),
          Expanded(child: _showLog ? _buildLogView() : _buildGaugeGrid(reading)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Alert logic
  // ---------------------------------------------------------------------------

  void _checkAlerts(OBDReading reading) {
    String? critical;
    String? warning;

    if (reading.o2SensorVoltage != null) {
      final est = AfrCalculator.estimatedAfrFromNarrowbandVoltage(
          reading.o2SensorVoltage!);
      final atHigh = (reading.rpm ?? 0) > 4000;
      if (AfrCalculator.isAfrDangerous(est, atHighRpm: atHigh)) {
        critical = est < 12.0
            ? '🔴 BABALA: Masyadong mataba ang halo (AFR est. ${est.toStringAsFixed(1)})! Carbon buildup risk!'
            : '🔴 BABALA: Masyadong payat sa high RPM (AFR est. ${est.toStringAsFixed(1)})! Detonation risk!';
      } else if (AfrCalculator.isAfrWarning(est)) {
        warning =
            '🟡 PAALALA: AFR approaching limits (est. ${est.toStringAsFixed(1)}) — bantayan.';
      }
    }

    if (reading.coolantTempC != null) {
      if (reading.coolantTempC! > 105) {
        critical =
            '🔴 BABALA: OVERHEATING! ${reading.coolantTempC}°C — suriin ang coolant agad!';
      } else if (reading.coolantTempC! > 95 && critical == null) {
        warning =
            '🟡 PAALALA: Mataas ang temperatura (${reading.coolantTempC}°C). Malapit sa limit.';
      }
    }

    if (reading.batteryVoltage != null &&
        reading.batteryVoltage! < 11.5 &&
        critical == null &&
        warning == null) {
      warning =
          '🟡 PAALALA: Mababa ang baterya (${reading.batteryVoltage!.toStringAsFixed(1)}V). Suriin ang charging system.';
    }

    if (critical != _criticalAlert || warning != _warningAlert) {
      setState(() {
        _criticalAlert = critical;
        _warningAlert = warning;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Gauge grid
  // ---------------------------------------------------------------------------

  Widget _buildGaugeGrid(OBDReading r) {
    final estAfr = r.o2SensorVoltage != null
        ? AfrCalculator.estimatedAfrFromNarrowbandVoltage(r.o2SensorVoltage!)
        : null;

    return GridView(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      children: [
        _GaugeCard(
          label: 'RPM',
          value: r.rpm?.toString(),
          unit: 'rpm',
          progress: r.rpm != null ? r.rpm! / 12000 : null,
          color: r.rpm != null && r.rpm! > 10000 ? AppColors.danger
              : r.rpm != null && r.rpm! > 8000 ? AppColors.warning
              : AppColors.safe,
          rangeLabel: '0 – 12,000',
        ),
        _GaugeCard(
          label: 'TPS',
          value: r.tpsPercent?.toStringAsFixed(1),
          unit: '%',
          progress: r.tpsPercent != null ? r.tpsPercent! / 100 : null,
          color: AppColors.primary,
          rangeLabel: '0 – 100%',
        ),
        _GaugeCard(
          label: 'AFR (est.)',
          value: estAfr?.toStringAsFixed(2),
          unit: ':1',
          progress: estAfr != null ? ((estAfr - 10) / 8).clamp(0, 1) : null,
          color: estAfr == null ? AppColors.textSecondary
              : AfrCalculator.isAfrDangerous(estAfr, atHighRpm: (r.rpm ?? 0) > 4000)
                  ? AppColors.danger
                  : AfrCalculator.isAfrWarning(estAfr)
                      ? AppColors.warning
                      : AppColors.safe,
          rangeLabel: '10.0 – 18.0',
          footnote: 'Narrowband estimate\nNOT calibrated AFR',
        ),
        _GaugeCard(
          label: 'Coolant Temp',
          value: r.coolantTempC?.toString(),
          unit: '°C',
          progress: r.coolantTempC != null
              ? (r.coolantTempC! / 120).clamp(0, 1)
              : null,
          color: r.coolantTempC == null ? AppColors.textSecondary
              : r.coolantTempC! > 105 ? AppColors.danger
              : r.coolantTempC! > 90 ? AppColors.warning
              : AppColors.safe,
          rangeLabel: '0 – 120°C',
        ),
        _GaugeCard(
          label: 'Battery',
          value: r.batteryVoltage?.toStringAsFixed(1),
          unit: 'V',
          progress: r.batteryVoltage != null
              ? ((r.batteryVoltage! - 10) / 6).clamp(0, 1)
              : null,
          color: r.batteryVoltage == null ? AppColors.textSecondary
              : r.batteryVoltage! < 11.5 ? AppColors.danger
              : r.batteryVoltage! < 12.5 ? AppColors.warning
              : AppColors.safe,
          rangeLabel: '10 – 16V',
        ),
        _GaugeCard(
          label: 'MAP Sensor',
          value: r.mapKpa?.toString(),
          unit: 'kPa',
          progress: r.mapKpa != null ? r.mapKpa! / 255 : null,
          color: AppColors.primary,
          rangeLabel: '0 – 255 kPa',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Log view
  // ---------------------------------------------------------------------------

  Widget _buildLogView() {
    if (_log.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storage_outlined, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Walang log pa.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.fiber_manual_record, size: 14),
            label: const Text('Magsimula ng Recording'),
            onPressed: () => setState(() => _isRecording = true),
          ),
        ]),
      );
    }

    final recent = _log.reversed.take(50).toList();
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.panel,
        child: Row(children: [
          Text(
            '${_log.length} readings logged',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Burahin'),
            onPressed: () => setState(() => _log.clear()),
          ),
        ]),
      ),
      // Table header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: AppColors.surface,
        child: const Row(children: [
          Expanded(flex: 3, child: Text('Time', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('RPM', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('TPS%', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('°C', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('V', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('O2V', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: recent.length,
          itemBuilder: (_, i) {
            final e = recent[i];
            final t = e.timestamp;
            final timeStr =
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5))),
              ),
              child: Row(children: [
                Expanded(flex: 3, child: Text(timeStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                Expanded(flex: 2, child: Text(e.rpm?.toString() ?? '--', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11))),
                Expanded(flex: 2, child: Text(e.tpsPercent?.toStringAsFixed(1) ?? '--', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11))),
                Expanded(flex: 2, child: Text(e.coolantTempC?.toString() ?? '--', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11))),
                Expanded(flex: 2, child: Text(e.batteryVoltage?.toStringAsFixed(1) ?? '--', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11))),
                Expanded(flex: 2, child: Text(e.o2SensorVoltage?.toStringAsFixed(3) ?? '--', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11))),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Status, alert, no-data banners
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar(BluetoothConnectionStatus status) {
    final isConnected = status == BluetoothConnectionStatus.connected;
    final isScanning = status == BluetoothConnectionStatus.scanning ||
        status == BluetoothConnectionStatus.connecting;
    final color = isConnected ? AppColors.safe : isScanning ? AppColors.warning : AppColors.textSecondary;
    final label = switch (status) {
      BluetoothConnectionStatus.connected => 'OBD Connected',
      BluetoothConnectionStatus.connecting => 'Connecting...',
      BluetoothConnectionStatus.scanning => 'Scanning for OBD...',
      BluetoothConnectionStatus.error => 'Connection Error',
      BluetoothConnectionStatus.disconnected => 'OBD Disconnected',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.panel,
      child: Row(children: [
        Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        if (_isRecording) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.danger),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text('REC ${_log.length}', style: const TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildAlertBanner(String message, {required bool isCritical}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isCritical
            ? AppColors.danger.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        child: Row(children: [
          Icon(
            isCritical ? Icons.warning : Icons.info_outline,
            color: isCritical ? AppColors.danger : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: isCritical ? AppColors.danger : AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              if (isCritical) _criticalAlert = null;
              else _warningAlert = null;
            }),
            child: Icon(Icons.close, size: 16,
                color: isCritical ? AppColors.danger : AppColors.warning),
          ),
        ]),
      );

  Widget _buildNoDataBanner() => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Walang OBD data. Hindi lahat ng motorcycle ay nagsasalita ng ELM327. '
              'Para sa mga carbureted o lumang modelo, gumamit ng dedicated scanner.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ]),
      );

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  void _exportCsv() {
    final buf = StringBuffer();
    buf.writeln('Timestamp,RPM,TPS%,CoolantTempC,BatteryV,O2SensorV,MAP_kPa');
    for (final r in _log) {
      buf.writeln(
          '${r.timestamp.toIso8601String()},'
          '${r.rpm ?? ""},'
          '${r.tpsPercent?.toStringAsFixed(1) ?? ""},'
          '${r.coolantTempC ?? ""},'
          '${r.batteryVoltage?.toStringAsFixed(2) ?? ""},'
          '${r.o2SensorVoltage?.toStringAsFixed(3) ?? ""},'
          '${r.mapKpa ?? ""}');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV generated — ${_log.length} readings, ${buf.length} bytes.'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gauge card widget
// ---------------------------------------------------------------------------

class _GaugeCard extends StatelessWidget {
  final String label;
  final String? value;
  final String unit;
  final double? progress; // 0.0 – 1.0 for the bar
  final Color color;
  final String rangeLabel;
  final String? footnote;

  const _GaugeCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.progress,
    required this.color,
    required this.rangeLabel,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue ? color.withValues(alpha: 0.5) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: hasValue ? color : AppColors.cardBorder,
                shape: BoxShape.circle,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              hasValue ? value! : '--',
              style: TextStyle(
                color: hasValue ? color : AppColors.textSecondary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(unit,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress?.clamp(0.0, 1.0),
              backgroundColor: AppColors.cardBorder,
              color: color,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(rangeLabel,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 9)),
          if (footnote != null)
            Text(footnote!,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    height: 1.3)),
        ],
      ),
    );
  }
}
