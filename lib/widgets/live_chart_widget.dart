import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/afr_calculator.dart';
import '../services/obd_service.dart';

/// Live scrolling charts for RPM, estimated AFR, and fuel trim trend.
/// Renders the last [maxPoints] readings from the recording log.
class LiveChartWidget extends StatelessWidget {
  final List<OBDReading> readings;
  static const maxPoints = 60;

  const LiveChartWidget({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.show_chart, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'Walang chart data pa.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'I-tap ang REC button at mag-drive para makita ang live charts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ]),
      );
    }

    final recent = readings.length > maxPoints
        ? readings.sublist(readings.length - maxPoints)
        : readings;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ChartCard(
          title: 'RPM',
          spots: _rpmSpots(recent),
          minY: 0,
          maxY: 14000,
          color: AppColors.primary,
          leftLabel: 'rpm',
          gridLines: const [2000, 4000, 6000, 8000, 10000, 12000],
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'AFR (est. from O2)',
          spots: _afrSpots(recent),
          minY: 10,
          maxY: 18,
          color: AppColors.safe,
          leftLabel: ':1',
          gridLines: const [12, 13, 14, 15, 16],
          dangerBands: const [
            _Band(y: 10, yEnd: 12, label: 'RICH'),
            _Band(y: 15.5, yEnd: 18, label: 'LEAN'),
          ],
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Short-Term Fuel Trim (STFT)',
          spots: _stftSpots(recent),
          minY: -25,
          maxY: 25,
          color: AppColors.warning,
          leftLabel: '%',
          gridLines: const [-10, -5, 0, 5, 10],
          zeroLine: true,
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Engine Load',
          spots: _loadSpots(recent),
          minY: 0,
          maxY: 100,
          color: AppColors.primary.withValues(alpha: 0.8),
          leftLabel: '%',
          gridLines: const [25, 50, 75],
        ),
      ],
    );
  }

  List<FlSpot> _rpmSpots(List<OBDReading> r) => _toSpots(r, (e) => e.rpm?.toDouble());
  List<FlSpot> _afrSpots(List<OBDReading> r) => _toSpots(
      r,
      (e) => e.o2SensorVoltage != null
          ? AfrCalculator.estimatedAfrFromNarrowbandVoltage(e.o2SensorVoltage!)
          : null);
  List<FlSpot> _stftSpots(List<OBDReading> r) =>
      _toSpots(r, (e) => e.fuelTrimShortTermPct);
  List<FlSpot> _loadSpots(List<OBDReading> r) =>
      _toSpots(r, (e) => e.engineLoadPercent);

  List<FlSpot> _toSpots(List<OBDReading> readings, double? Function(OBDReading) val) {
    final spots = <FlSpot>[];
    for (int i = 0; i < readings.length; i++) {
      final v = val(readings[i]);
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    return spots;
  }
}

class _Band {
  final double y;
  final double yEnd;
  final String label;
  const _Band({required this.y, required this.yEnd, required this.label});
}

class _ChartCard extends StatelessWidget {
  final String title;
  final List<FlSpot> spots;
  final double minY;
  final double maxY;
  final Color color;
  final String leftLabel;
  final List<double> gridLines;
  final bool zeroLine;
  final List<_Band> dangerBands;

  const _ChartCard({
    required this.title,
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.color,
    required this.leftLabel,
    this.gridLines = const [],
    this.zeroLine = false,
    this.dangerBands = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(leftLabel,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: spots.isEmpty
                ? Center(
                    child: Text('No data',
                        style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                            fontSize: 11)))
                : LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (y) {
                          final isGrid = gridLines.contains(y);
                          final isZero = zeroLine && y == 0;
                          if (!isGrid && !isZero) return FlLine(color: Colors.transparent);
                          return FlLine(
                            color: isZero
                                ? AppColors.textSecondary.withValues(alpha: 0.5)
                                : AppColors.cardBorder,
                            strokeWidth: isZero ? 1.5 : 0.8,
                            dashArray: isZero ? [4, 4] : null,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: (maxY - minY) / 4,
                            getTitlesWidget: (v, _) {
                              if (!gridLines.contains(v) && !(zeroLine && v == 0)) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1),
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 9),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          for (final band in dangerBands) ...[
                            HorizontalLine(
                              y: (band.y + band.yEnd) / 2,
                              color: AppColors.danger.withValues(alpha: 0.08),
                              strokeWidth: (band.yEnd - band.y) *
                                  120 /
                                  (maxY - minY),
                            ),
                          ],
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          color: color,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.06),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
