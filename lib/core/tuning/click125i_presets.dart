import 'tune_preset.dart';

/// Tuning presets for the Honda Click 125i (Keihin PGM-FI ECU).
///
/// Map zone indices reference the 12×12 grid defined in EcuRegistry.hondaClick125i:
/// RPM rows: [1000,1500,2000,2500,3000,3500,4000,4500,5000,6000,7000,8000]
/// TPS cols: [0,10,20,30,40,50,60,70,80,90,95,100]
///
/// IMPORTANT: All percentage/absolute deltas are conservative and within
/// hardware-documented safe limits. Actual ROM impact depends on confirmed
/// map offsets — presets are marked with confidenceScore < 1.0 until
/// EcuVerificationManager confirms the Click ROM structure.
class Click125iPresets {
  Click125iPresets._();

  static const String _ecuId = 'keihin_click125i_pgmfi';

  // ── RPM row indices ───────────────────────────────────────────────────────
  // 0=1000, 1=1500, 2=2000, 3=2500, 4=3000, 5=3500, 6=4000
  // 7=4500, 8=5000, 9=6000, 10=7000, 11=8000

  // ── TPS col indices ───────────────────────────────────────────────────────
  // 0=0%, 1=10%, 2=20%, 3=30%, 4=40%, 5=50%, 6=60%
  // 7=70%, 8=80%, 9=90%, 10=95%, 11=100%

  // ──────────────────────────────────────────────────────────────────────────
  // 1. ECO TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset ecoTune = TunePreset(
    id: 'click125i_eco',
    name: 'Eco Tune',
    subtitle: 'Maximum fuel savings for daily commuting',
    category: PresetCategory.daily,
    ecuId: _ecuId,
    confidenceScore: 0.75,
    riskLevel: PresetRisk.safe,
    recommendedOctaneMin: 91,
    afrTargetExplanation:
        'Targets 14.0–14.4 AFR at cruise (slightly leaner than stock 13.5–14.2). '
        'Wide-open throttle kept near stock 13.0 for safety.',
    benefits: [
      'Estimated 8–12% fuel consumption improvement at steady cruise',
      'Cleaner exhaust at light throttle',
      'Cooler running temperature at low load',
    ],
    sideEffects: [
      'Slightly less throttle response at partial load',
      'May feel flat below 3000 RPM',
      'Not suitable for modified exhaust (lean risk)',
    ],
    warnings: [
      'Do not use with free-flow exhaust — combined lean effect is unsafe',
      'Only for stock air filter and exhaust',
      'Not suitable for city stop-and-go riding in extreme heat',
    ],
    estimatedPowerGainPct: -2.0,
    estimatedFuelChangePct: -10.0,
    deltas: [
      // Lean cruise fuel -4% (2000–5000 RPM × 20–60% TPS)
      MapZoneDelta(
        mapName: 'fuel_map',
        rpmRowLow: 2, rpmRowHigh: 8, // 2000–5000 RPM
        tpsColLow: 2, tpsColHigh: 6, // 20–60% TPS
        percentDelta: -4.0,
      ),
      // Advance ignition +1° at cruise for efficiency
      MapZoneDelta(
        mapName: 'ignition_map',
        rpmRowLow: 2, rpmRowHigh: 7, // 2000–4500 RPM
        tpsColLow: 1, tpsColHigh: 5, // 10–50% TPS
        absoluteDelta: 1.0,
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────
  // 2. STREET TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset streetTune = TunePreset(
    id: 'click125i_street',
    name: 'Street Tune',
    subtitle: 'Balanced daily ride with better throttle feel',
    category: PresetCategory.daily,
    ecuId: _ecuId,
    confidenceScore: 0.78,
    riskLevel: PresetRisk.safe,
    recommendedOctaneMin: 91,
    afrTargetExplanation:
        'Maintains stock cruise AFR 13.5–14.2. Slight enrichment 3000–4500 RPM '
        'for better mid-range pull in traffic. WOT stays stock 13.0.',
    benefits: [
      'Smoother throttle response in stop-and-go traffic',
      'Better pull from 3000–4500 RPM (sweet spot for urban riding)',
      'Stock fuel consumption maintained',
    ],
    sideEffects: [
      'No significant change from stock in most conditions',
    ],
    warnings: [
      'Safe for stock exhaust and air filter',
    ],
    estimatedPowerGainPct: 3.0,
    estimatedFuelChangePct: 0.0,
    deltas: [
      // Enrich mid-range +4% (3000–4500 RPM × 30–70% TPS)
      MapZoneDelta(
        mapName: 'fuel_map',
        rpmRowLow: 4, rpmRowHigh: 7, // 3000–4500 RPM
        tpsColLow: 3, tpsColHigh: 7, // 30–70% TPS
        percentDelta: 4.0,
      ),
      // Advance timing +1° in mid-range
      MapZoneDelta(
        mapName: 'ignition_map',
        rpmRowLow: 4, rpmRowHigh: 7,
        tpsColLow: 3, tpsColHigh: 6,
        absoluteDelta: 1.0,
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────
  // 3. TOURING TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset touringTune = TunePreset(
    id: 'click125i_touring',
    name: 'Touring Tune',
    subtitle: 'Smooth stable power for long-distance riding',
    category: PresetCategory.specialized,
    ecuId: _ecuId,
    confidenceScore: 0.76,
    riskLevel: PresetRisk.safe,
    recommendedOctaneMin: 91,
    afrTargetExplanation:
        'Optimizes 2500–5000 RPM range (typical highway cruise band). '
        'Slightly richer at cruise for cooler engine temperature. '
        'Stable AFR across throttle changes for predictable feel.',
    benefits: [
      'Smoother throttle transitions at highway speed',
      'More stable AFR at steady 80–100 km/h cruise',
      'Reduced engine heat during sustained high-speed runs',
    ],
    sideEffects: [
      'Slight reduction in peak top speed',
      'Marginally higher fuel consumption vs eco',
    ],
    warnings: [
      'Designed for sustained highway use, not city stop-and-go',
      'Check engine cooling before long-distance rides regardless of tune',
    ],
    estimatedPowerGainPct: 2.0,
    estimatedFuelChangePct: 2.0,
    deltas: [
      // Enrich steady cruise 2500–5000 RPM × 40–70% TPS by +5%
      MapZoneDelta(
        mapName: 'fuel_map',
        rpmRowLow: 3, rpmRowHigh: 8, // 2500–5000 RPM
        tpsColLow: 4, tpsColHigh: 7, // 40–70% TPS
        percentDelta: 5.0,
      ),
      // Stabilize timing (no advance at cruise — heat management priority)
      // No ignition delta for touring — stock timing is already conservative
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────
  // 4. RACING TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset racingTune = TunePreset(
    id: 'click125i_racing',
    name: 'Racing Tune',
    subtitle: 'Maximum performance — track and competition use only',
    category: PresetCategory.performance,
    ecuId: _ecuId,
    confidenceScore: 0.70,
    riskLevel: PresetRisk.advanced,
    recommendedOctaneMin: 97,
    afrTargetExplanation:
        'Targets 12.8–13.2 AFR at WOT for maximum power. '
        'Cruise AFR slightly lean 14.0 for throttle response. '
        'Maximum safe ignition advance added at high RPM.',
    benefits: [
      'Estimated +8–12% peak power at 6000–8000 RPM',
      'Sharper throttle response throughout rev range',
      'Maximum performance within stock internals limits',
    ],
    sideEffects: [
      'Significantly increased engine heat — requires frequent cooldown stops',
      'Higher fuel consumption (est. +20%)',
      'Reduced engine longevity at sustained high RPM',
      'Requires 97+ RON fuel — lower octane WILL cause knock',
    ],
    warnings: [
      'TRACK AND COMPETITION USE ONLY — not safe for street daily use',
      '97+ RON premium fuel MANDATORY — engine damage risk on lower octane',
      'Engine temperature must be monitored — stop if overheating',
      'Not recommended for engines with more than 30,000 km',
      'Air-cooled engine: maximum 15-minute sustained high-RPM sessions',
    ],
    estimatedPowerGainPct: 10.0,
    estimatedFuelChangePct: 20.0,
    deltas: [
      // Enrich WOT 5000–8000 RPM × 70–100% TPS by +8%
      MapZoneDelta(
        mapName: 'fuel_map',
        rpmRowLow: 8, rpmRowHigh: 11, // 5000–8000 RPM
        tpsColLow: 7, tpsColHigh: 11, // 70–100% TPS
        percentDelta: 8.0,
      ),
      // Advance timing +3° at high RPM (pump fuel limit: +3°, premium: +5°, using +3°)
      MapZoneDelta(
        mapName: 'ignition_map',
        rpmRowLow: 8, rpmRowHigh: 11,
        tpsColLow: 6, tpsColHigh: 11,
        absoluteDelta: 3.0,
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────
  // 5. PIPE TUNE (free-flow exhaust compensation)
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset pipeTune = TunePreset(
    id: 'click125i_pipe',
    name: 'Pipe Tune',
    subtitle: 'Fuel correction for free-flow exhaust / slip-on',
    category: PresetCategory.specialized,
    ecuId: _ecuId,
    confidenceScore: 0.80,
    riskLevel: PresetRisk.caution,
    recommendedOctaneMin: 91,
    afrTargetExplanation:
        'Compensates for the lean condition caused by free-flow exhaust. '
        'Enriches the known lean zone 3000–4500 RPM × 20–60% TPS by 10% '
        '(matching Click125iPack.freeFlowEnrichmentPercent). '
        'WOT also enriched to target 12.8–13.2 AFR.',
    benefits: [
      'Corrects dangerous lean spike caused by free-flow exhaust',
      'Restores power lost from lean condition',
      'Brings AFR back to 13.2–13.8 cruise target',
    ],
    sideEffects: [
      'Slightly higher fuel consumption than stock',
      'Exhaust note unchanged (map change only)',
    ],
    warnings: [
      'Requires free-flow exhaust or slip-on to be already fitted',
      'Do NOT apply to stock exhaust — will run rich',
      'Recommended: verify with wideband AFR monitor after flashing',
      'Stock air filter assumed — if pod filter fitted, additional +5% WOT needed',
    ],
    requiredMods: ['Free-flow exhaust or slip-on'],
    estimatedPowerGainPct: 5.0,
    estimatedFuelChangePct: 5.0,
    deltas: [
      // Enrich known lean zone: 3000–4500 RPM × 20–60% TPS +10%
      MapZoneDelta(
        mapName: 'fuel_map',
        rpmRowLow: 4, rpmRowHigh: 7,  // 3000–4500 RPM (rows 4–7)
        tpsColLow: 2, tpsColHigh: 6,  // 20–60% TPS (cols 2–6)
        percentDelta: 10.0,
      ),
      // Enrich WOT +6% (5000–8000 RPM × 70–100% TPS)
      MapZoneDelta(
        mapName: 'fuel_map',
        rpmRowLow: 8, rpmRowHigh: 11,
        tpsColLow: 7, tpsColHigh: 11,
        percentDelta: 6.0,
      ),
      // Advance mid-range timing +1° (exhaust scavenging effect)
      MapZoneDelta(
        mapName: 'ignition_map',
        rpmRowLow: 4, rpmRowHigh: 8,
        tpsColLow: 3, tpsColHigh: 7,
        absoluteDelta: 1.0,
      ),
    ],
  );

  /// All Click 125i presets in display order.
  static const List<TunePreset> all = [
    ecoTune,
    streetTune,
    touringTune,
    pipeTune,
    racingTune,
  ];
}
