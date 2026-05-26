import '../binary/rom_parser.dart';
import '../ecu/ecu_definition.dart';
import '../../ai/model_packs/click125i_pack.dart';
import '../../ai/model_packs/aerox155_pack.dart';

// ── Risk result models ────────────────────────────────────────────────────────

enum CellRisk { safe, lean, rich, timingHigh, timingLow, outOfRange }

class CellRiskResult {
  final int row;
  final int col;
  final CellRisk risk;
  final String mapName;
  final double physicalValue;
  final String explanation;

  const CellRiskResult({
    required this.row,
    required this.col,
    required this.risk,
    required this.mapName,
    required this.physicalValue,
    required this.explanation,
  });
}

enum HeatRisk { cool, warm, hot, critical }

class RiskReport {
  final List<CellRiskResult> cellRisks;
  final HeatRisk overallHeatRisk;
  final double estimatedKnockRiskPct;  // 0–100
  final String summary;
  final List<String> actionItems;
  final bool blocksFlash;

  const RiskReport({
    required this.cellRisks,
    required this.overallHeatRisk,
    required this.estimatedKnockRiskPct,
    required this.summary,
    required this.actionItems,
    required this.blocksFlash,
  });

  bool get hasAnyCritical =>
      cellRisks.any((c) => c.risk == CellRisk.outOfRange) || blocksFlash;

  List<CellRiskResult> get dangerCells =>
      cellRisks.where((c) => c.risk != CellRisk.safe).toList();
}

// ── Risk analyzer ─────────────────────────────────────────────────────────────

/// Performs live risk analysis on a ParsedRom against ECU-specific limits.
///
/// Used by the professional map editor to show overlay warnings and
/// block flashing when values exceed hard limits.
class RiskAnalyzer {
  RiskAnalyzer._();

  /// Analyze all maps in [rom] for the given [ecu] and return a [RiskReport].
  static RiskReport analyze(ParsedRom rom, EcuDefinition ecu) {
    final limits = _LimitsFor.ecu(ecu);
    final cellRisks = <CellRiskResult>[];

    for (final entry in rom.maps.entries) {
      final mapName = entry.key;
      final extracted = entry.value;
      final desc = extracted.descriptor;

      for (var r = 0; r < desc.rows; r++) {
        for (var c = 0; c < desc.cols; c++) {
          final v = extracted.values[r][c];
          final risk = _classifyCell(mapName, v, desc, limits, ecu);
          if (risk != null) cellRisks.add(risk.copyWith(row: r, col: c));
        }
      }
    }

    final heatRisk = _estimateHeat(cellRisks, limits);
    final knockRisk = _estimateKnock(rom, ecu, limits);
    final blocksFlash = cellRisks.any((c) => c.risk == CellRisk.outOfRange);

    final actionItems = _buildActionItems(cellRisks, knockRisk, heatRisk);

    return RiskReport(
      cellRisks: cellRisks,
      overallHeatRisk: heatRisk,
      estimatedKnockRiskPct: knockRisk,
      summary: _buildSummary(cellRisks, heatRisk, knockRisk, blocksFlash),
      actionItems: actionItems,
      blocksFlash: blocksFlash,
    );
  }

  /// Analyze a single cell change before it is committed.
  /// Returns a warning string if dangerous, null if safe.
  static String? analyzeProposedCellChange({
    required String mapName,
    required double proposedValue,
    required int row,
    required int col,
    required MapDescriptor descriptor,
    required EcuDefinition ecu,
    required int rpmAtRow,
    required int tpsAtCol,
  }) {
    final limits = _LimitsFor.ecu(ecu);

    if (proposedValue < descriptor.safeMin || proposedValue > descriptor.safeMax) {
      return 'HARD LIMIT: ${descriptor.name} value ${proposedValue.toStringAsFixed(1)} '
          '${descriptor.unit} is outside the safe range '
          '[${descriptor.safeMin}–${descriptor.safeMax}].';
    }

    if (_isFuelMap(mapName)) {
      // Conceptual AFR check for known-lean values
      if (proposedValue < descriptor.safeMin * 1.05) {
        return 'WARNING: Fuel value ${proposedValue.toStringAsFixed(2)} ${descriptor.unit} '
            'at $rpmAtRow RPM / $tpsAtCol% TPS may cause lean AFR below ${limits.afrMin}. '
            'Risk: overheating, detonation.';
      }
    }

    if (_isIgnitionMap(mapName)) {
      final maxTiming = limits.maxTimingBtdc;
      if (proposedValue > maxTiming) {
        return 'HARD LIMIT: ${proposedValue.toStringAsFixed(1)}° BTDC exceeds '
            'maximum safe timing of $maxTiming° BTDC for ${ecu.displayName}.\n'
            'Risk: detonation, piston damage, engine failure.';
      }

      final stockBase = _stockTimingAt(rpmAtRow, tpsAtCol, ecu);
      final advance = proposedValue - stockBase;
      final maxAdvance = limits.maxAdvancePump;
      if (advance > maxAdvance) {
        return 'WARNING: +${advance.toStringAsFixed(1)}° timing advance at '
            '$rpmAtRow RPM / $tpsAtCol% TPS exceeds recommended maximum '
            'of +$maxAdvance° (pump fuel).\n'
            'With premium 97+ RON fuel, maximum is +${limits.maxAdvancePremium}°.\n'
            'Risk: knock, detonation, piston damage.';
      }
    }

    return null;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static _CellRiskResult? _classifyCell(
    String mapName,
    double value,
    MapDescriptor desc,
    _Limits limits,
    EcuDefinition ecu,
  ) {
    if (value < desc.safeMin || value > desc.safeMax) {
      return _CellRiskResult(
        risk: CellRisk.outOfRange,
        mapName: mapName,
        physicalValue: value,
        explanation: 'Value ${value.toStringAsFixed(2)} ${desc.unit} '
            'is outside safe range [${desc.safeMin}–${desc.safeMax}]. '
            'Flash blocked until corrected.',
      );
    }

    if (_isFuelMap(mapName)) {
      // Conceptual lean/rich detection based on position in safe range
      final rangeSize = desc.safeMax - desc.safeMin;
      final leanThreshold = desc.safeMin + rangeSize * 0.08;
      final richThreshold = desc.safeMax - rangeSize * 0.05;

      if (value <= leanThreshold) {
        return _CellRiskResult(
          risk: CellRisk.lean,
          mapName: mapName,
          physicalValue: value,
          explanation: 'Fuel value ${value.toStringAsFixed(2)} is near lean limit. '
              'Risk of overheating or detonation.',
        );
      }
      if (value >= richThreshold) {
        return _CellRiskResult(
          risk: CellRisk.rich,
          mapName: mapName,
          physicalValue: value,
          explanation: 'Fuel value ${value.toStringAsFixed(2)} is near rich limit. '
              'Risk of catalyst fouling, poor fuel economy.',
        );
      }
    }

    if (_isIgnitionMap(mapName)) {
      if (value > limits.maxTimingBtdc) {
        return _CellRiskResult(
          risk: CellRisk.outOfRange,
          mapName: mapName,
          physicalValue: value,
          explanation: '${value.toStringAsFixed(1)}° BTDC exceeds '
              'hard limit of ${limits.maxTimingBtdc}°. '
              'Detonation and piston damage risk.',
        );
      }
      if (value > limits.maxTimingBtdc - 3) {
        return _CellRiskResult(
          risk: CellRisk.timingHigh,
          mapName: mapName,
          physicalValue: value,
          explanation: '${value.toStringAsFixed(1)}° BTDC is within 3° of the hard limit. '
              'High knock risk — premium fuel required.',
        );
      }
    }

    return null;
  }

  static HeatRisk _estimateHeat(List<CellRiskResult> risks, _Limits limits) {
    final leanCount = risks.where((r) => r.risk == CellRisk.lean).length;
    final outCount = risks.where((r) => r.risk == CellRisk.outOfRange).length;
    final highTimingCount = risks.where((r) => r.risk == CellRisk.timingHigh).length;

    if (outCount > 0 || leanCount > 10) return HeatRisk.critical;
    if (leanCount > 4 || highTimingCount > 6) return HeatRisk.hot;
    if (leanCount > 0 || highTimingCount > 0) return HeatRisk.warm;
    return HeatRisk.cool;
  }

  static double _estimateKnock(
      ParsedRom rom, EcuDefinition ecu, _Limits limits) {
    final ignMap = rom.maps[_isAerox(ecu) ? 'ignition_timing' : 'ignition_map'];
    if (ignMap == null) return 0;

    var riskSum = 0.0;
    var count = 0;
    for (var r = 0; r < ignMap.descriptor.rows; r++) {
      for (var c = 0; c < ignMap.descriptor.cols; c++) {
        final v = ignMap.values[r][c];
        final threshold = limits.maxTimingBtdc - 5;
        if (v > threshold) {
          riskSum += (v - threshold) / 5.0;
          count++;
        }
      }
    }
    return count > 0 ? (riskSum / count * 100).clamp(0, 100) : 0;
  }

  static String _buildSummary(
    List<CellRiskResult> risks,
    HeatRisk heat,
    double knock,
    bool blocksFlash,
  ) {
    if (blocksFlash) {
      return 'FLASH BLOCKED: ${risks.where((r) => r.risk == CellRisk.outOfRange).length} '
          'cell(s) outside absolute safe limits.';
    }
    if (heat == HeatRisk.critical) return 'CRITICAL heat risk — tune is unsafe.';
    if (heat == HeatRisk.hot) {
      return 'HIGH heat risk — ${risks.length} cells need attention. '
          'Premium fuel required.';
    }
    if (risks.isEmpty) return 'All values within safe range.';
    return '${risks.length} cell(s) warrant review — see action items.';
  }

  static List<String> _buildActionItems(
    List<CellRiskResult> risks,
    double knockRisk,
    HeatRisk heat,
  ) {
    final items = <String>[];
    final leanCells = risks.where((r) => r.risk == CellRisk.lean).length;
    final outCells = risks.where((r) => r.risk == CellRisk.outOfRange).length;
    final highTiming = risks.where((r) => r.risk == CellRisk.timingHigh).length;

    if (outCells > 0) {
      items.add('Correct $outCells out-of-range cell(s) before flash is allowed');
    }
    if (leanCells > 3) {
      items.add('$leanCells lean fuel cells detected — enrich or restore to stock');
    }
    if (highTiming > 0) {
      items.add('$highTiming timing cell(s) near limit — use premium fuel minimum');
    }
    if (knockRisk > 60) {
      items.add('Knock risk ${knockRisk.toStringAsFixed(0)}% — retard timing or use 97 RON');
    }
    if (heat == HeatRisk.hot || heat == HeatRisk.critical) {
      items.add('Tune runs hot — ensure coolant/oil is fresh and fan operates correctly');
    }
    return items;
  }

  static bool _isFuelMap(String name) =>
      name.contains('fuel') || name.contains('injection');

  static bool _isIgnitionMap(String name) =>
      name.contains('ignition') || name.contains('timing');

  static bool _isAerox(EcuDefinition ecu) => ecu.id.contains('aerox');

  static double _stockTimingAt(int rpm, int tps, EcuDefinition ecu) {
    if (_isAerox(ecu)) {
      if (rpm < 2000) return Aerox155Pack.baseTimingIdleBtdc;
      if (rpm < 6000) return Aerox155Pack.baseTimingCruiseBtdc;
      return Aerox155Pack.baseTimingHighRpmBtdc;
    }
    return Click125iPack.baseTimingBtdc;
  }
}

// ── Internal limit model ──────────────────────────────────────────────────────

class _Limits {
  final double afrMin;
  final double afrMax;
  final double maxTimingBtdc;
  final double maxAdvancePump;
  final double maxAdvancePremium;

  const _Limits({
    required this.afrMin,
    required this.afrMax,
    required this.maxTimingBtdc,
    required this.maxAdvancePump,
    required this.maxAdvancePremium,
  });
}

class _LimitsFor {
  static _Limits ecu(EcuDefinition ecu) {
    if (ecu.id.contains('click')) {
      return const _Limits(
        afrMin: Click125iPack.absoluteAfrMin,
        afrMax: Click125iPack.absoluteAfrMax,
        maxTimingBtdc: Click125iPack.maxTimingBtdc,
        maxAdvancePump: Click125iPack.safeAdvancePumpFuel,
        maxAdvancePremium: Click125iPack.safeAdvancePremiumFuel,
      );
    }
    return const _Limits(
      afrMin: Aerox155Pack.absoluteAfrMin,
      afrMax: Aerox155Pack.absoluteAfrMax,
      maxTimingBtdc: Aerox155Pack.maxTimingBtdc,
      maxAdvancePump: Aerox155Pack.safeAdvancePumpFuel,
      maxAdvancePremium: Aerox155Pack.safeAdvancePremiumFuel,
    );
  }
}

// ── Builder helpers ───────────────────────────────────────────────────────────

class _CellRiskResult {
  final CellRisk risk;
  final String mapName;
  final double physicalValue;
  final String explanation;

  const _CellRiskResult({
    required this.risk,
    required this.mapName,
    required this.physicalValue,
    required this.explanation,
  });

  CellRiskResult copyWith({required int row, required int col}) => CellRiskResult(
        row: row,
        col: col,
        risk: risk,
        mapName: mapName,
        physicalValue: physicalValue,
        explanation: explanation,
      );
}
