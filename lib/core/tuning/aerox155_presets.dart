import 'tune_preset.dart';

/// Tuning presets for the Yamaha Aerox 155 VVA (Shindengen RH850 ECU).
///
/// Map zone indices reference the 16×16 grid in EcuRegistry.yamahaAerox155:
/// RPM rows: [1000,1500,2000,2500,3000,3500,4000,4500,5000,5500,6000,6500,7000,7500,8000,9000]
/// TPS cols: [0,5,10,15,20,30,40,50,60,70,80,90,95,97,99,100]
///
/// CRITICAL: VVA transition occurs at row 10 (6000 RPM). Any preset touching
/// rows 9–12 (5500–7000 RPM) MUST include VVA transition enrichment.
///
/// IMPORTANT: Confidence scores reflect that Aerox ROM offsets are community-estimated.
/// EcuVerificationManager must mark ECU as verified before presets are applied.
class Aerox155Presets {
  Aerox155Presets._();

  static const String _ecuId = 'shindengen_aerox155_rh850';

  // ── RPM row indices (0-based) ────────────────────────────────────────────
  // 0=1000, 1=1500, 2=2000, 3=2500, 4=3000, 5=3500, 6=4000, 7=4500
  // 8=5000, 9=5500, 10=6000(VVA!), 11=6500, 12=7000, 13=7500, 14=8000, 15=9000

  // ── TPS col indices (0-based) ────────────────────────────────────────────
  // 0=0%, 1=5%, 2=10%, 3=15%, 4=20%, 5=30%, 6=40%, 7=50%
  // 8=60%, 9=70%, 10=80%, 11=90%, 12=95%, 13=97%, 14=99%, 15=100%

  // ──────────────────────────────────────────────────────────────────────────
  // 1. VVA SMOOTH TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset vvaSmoothTune = TunePreset(
    id: 'aerox155_vva_smooth',
    name: 'VVA Smooth Tune',
    subtitle: 'Eliminates VVA transition lean spike for a seamless powerband',
    category: PresetCategory.daily,
    ecuId: _ecuId,
    confidenceScore: 0.75,
    riskLevel: PresetRisk.safe,
    recommendedOctaneMin: 91,
    afrTargetExplanation:
        'Targets 13.0–13.5 AFR through the VVA transition zone (5500–6500 RPM). '
        'Stock AFR dips lean during cam switch — this preset pre-enriches '
        'the transition window by 6% (Aerox155Pack.vvaTransitionEnrichmentPercent). '
        'Cruise and WOT AFR unchanged from stock.',
    benefits: [
      'Eliminates the flat spot / hesitation at VVA engagement (~6000 RPM)',
      'Smoother powerband transition from low-cam to high-cam mode',
      'Improved rideability during partial-throttle acceleration',
    ],
    sideEffects: [
      'No significant change to peak power',
      'Marginal fuel consumption increase in the 5500–6500 RPM zone',
    ],
    warnings: [
      'Does not change VVA engagement RPM — this requires VVA map editing in Pro mode',
      'Assumes stock exhaust and air filter',
    ],
    estimatedPowerGainPct: 2.0,
    estimatedFuelChangePct: 1.5,
    deltas: [
      // Enrich VVA transition zone: 5500–6500 RPM × 40–100% TPS +6%
      MapZoneDelta(
        mapName: 'fuel_injection',
        rpmRowLow: 9, rpmRowHigh: 11,  // 5500–6500 RPM (VVA zone)
        tpsColLow: 6, tpsColHigh: 15,  // 40–100% TPS
        percentDelta: 6.0,
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────
  // 2. AGGRESSIVE VVA TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset aggressiveVvaTune = TunePreset(
    id: 'aerox155_vva_aggressive',
    name: 'Aggressive VVA Tune',
    subtitle: 'Maximum high-RPM performance with VVA optimization',
    category: PresetCategory.performance,
    ecuId: _ecuId,
    confidenceScore: 0.70,
    riskLevel: PresetRisk.advanced,
    recommendedOctaneMin: 95,
    afrTargetExplanation:
        'Targets 12.5–13.0 AFR at WOT post-VVA (6000–9000 RPM). '
        'VVA transition zone enriched 10% to prevent lean spike under aggressive acceleration. '
        'Ignition advanced +2° at high RPM for maximum power extraction.',
    benefits: [
      'Estimated +10–15% power increase at 6000–9000 RPM',
      'Sharper throttle response post-VVA transition',
      'Stronger pull through high-RPM powerband',
    ],
    sideEffects: [
      'Increased engine heat — liquid cooling handles this better than air-cooled',
      'Higher fuel consumption (est. +15%)',
      'Requires 95+ RON — knock risk on lower octane at advanced timing',
    ],
    warnings: [
      '95+ RON fuel MANDATORY — knock risk at advanced timing with lower octane',
      'Monitor coolant temperature — stop if temp exceeds normal range',
      'Not recommended with open exhaust without additional WOT enrichment',
      'Knock events must be monitored via OBD after first ride',
    ],
    estimatedPowerGainPct: 12.0,
    estimatedFuelChangePct: 15.0,
    deltas: [
      // Enrich VVA transition zone 10% (5500–6500 RPM × 40–100% TPS)
      MapZoneDelta(
        mapName: 'fuel_injection',
        rpmRowLow: 9, rpmRowHigh: 11,
        tpsColLow: 6, tpsColHigh: 15,
        percentDelta: 10.0,
      ),
      // Enrich post-VVA WOT: 6500–9000 RPM × 70–100% TPS +8%
      MapZoneDelta(
        mapName: 'fuel_injection',
        rpmRowLow: 11, rpmRowHigh: 15,
        tpsColLow: 9, tpsColHigh: 15,
        percentDelta: 8.0,
      ),
      // Advance timing +2° at high-RPM WOT (within Aerox155Pack.safeAdvancePremiumFuel limit)
      MapZoneDelta(
        mapName: 'ignition_timing',
        rpmRowLow: 10, rpmRowHigh: 15, // 6000–9000 RPM
        tpsColLow: 9, tpsColHigh: 15,  // 70–100% TPS
        absoluteDelta: 2.0,
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────
  // 3. DRAG TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset dragTune = TunePreset(
    id: 'aerox155_drag',
    name: 'Drag Tune',
    subtitle: 'Maximum acceleration — standing quarter mile and sprint',
    category: PresetCategory.performance,
    ecuId: _ecuId,
    confidenceScore: 0.68,
    riskLevel: PresetRisk.advanced,
    recommendedOctaneMin: 97,
    afrTargetExplanation:
        'Targets 12.3–12.8 AFR across the entire power range for maximum fuel '
        'energy delivery. VVA transition zone enriched 12% to eliminate any power '
        'interruption. Max safe timing advance applied (+4° at WOT with 97 RON).',
    benefits: [
      'Maximum acceleration across full RPM range',
      'No power interruption at VVA transition',
      'Estimated +15–18% quarter-mile improvement',
    ],
    sideEffects: [
      'Extremely high fuel consumption — not suitable for street use',
      'Significant engine heat increase — coolant must be in perfect condition',
      'Transmission/CVT wear accelerated',
      'Engine longevity reduced at sustained maximum load',
    ],
    warnings: [
      'DRAG STRIP AND COMPETITION USE ONLY — NOT FOR STREET',
      '97+ RON premium fuel REQUIRED — NO EXCEPTIONS',
      'Coolant temperature must be checked before every drag run',
      'Maximum engine load must not exceed 5 minutes continuously',
      'Spark plugs must be inspected and replaced on schedule',
      'CVT must be drag-tuned separately for optimal launch',
    ],
    estimatedPowerGainPct: 16.0,
    estimatedFuelChangePct: 30.0,
    deltas: [
      // Maximum enrichment across all load zones
      MapZoneDelta(
        mapName: 'fuel_injection',
        rpmRowLow: 4, rpmRowHigh: 15,  // 3000–9000 RPM
        tpsColLow: 8, tpsColHigh: 15,  // 60–100% TPS
        percentDelta: 12.0,
      ),
      // VVA transition extra enrichment
      MapZoneDelta(
        mapName: 'fuel_injection',
        rpmRowLow: 9, rpmRowHigh: 11,  // 5500–6500 RPM
        tpsColLow: 6, tpsColHigh: 15,
        percentDelta: 4.0,            // extra +4% on top of above
      ),
      // Maximum timing advance within Aerox premium fuel limit (+4°)
      MapZoneDelta(
        mapName: 'ignition_timing',
        rpmRowLow: 6, rpmRowHigh: 15,  // 4000–9000 RPM
        tpsColLow: 9, tpsColHigh: 15,
        absoluteDelta: 4.0,
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────
  // 4. DAILY TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset dailyTune = TunePreset(
    id: 'aerox155_daily',
    name: 'Daily Tune',
    subtitle: 'Improved throttle response and mid-range for everyday riding',
    category: PresetCategory.daily,
    ecuId: _ecuId,
    confidenceScore: 0.78,
    riskLevel: PresetRisk.safe,
    recommendedOctaneMin: 91,
    afrTargetExplanation:
        'Maintains stock cruise AFR 13.8–14.4. Enriches 3000–5500 RPM '
        'mid-range by 5% for better city pull. VVA transition zone enriched '
        'to eliminate stock flat spot. No timing change — safety first.',
    benefits: [
      'Better pull from 3000–5000 RPM for city overtaking',
      'Smoother VVA transition on daily streets',
      'Stock fuel consumption maintained at light throttle',
    ],
    sideEffects: [
      'Negligible change from stock in most conditions',
    ],
    warnings: [
      'Safe for stock exhaust and air filter',
      'Compatible with 91 RON regular pump fuel',
    ],
    estimatedPowerGainPct: 4.0,
    estimatedFuelChangePct: 2.0,
    deltas: [
      // Mid-range enrichment: 3000–5500 RPM × 30–70% TPS +5%
      MapZoneDelta(
        mapName: 'fuel_injection',
        rpmRowLow: 4, rpmRowHigh: 9,   // 3000–5500 RPM
        tpsColLow: 5, tpsColHigh: 9,   // 30–70% TPS
        percentDelta: 5.0,
      ),
      // VVA transition enrichment: 5500–6500 RPM +6%
      MapZoneDelta(
        mapName: 'fuel_injection',
        rpmRowLow: 9, rpmRowHigh: 11,
        tpsColLow: 6, tpsColHigh: 15,
        percentDelta: 6.0,
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────
  // 5. FUEL ECONOMY TUNE
  // ──────────────────────────────────────────────────────────────────────────
  static const TunePreset fuelEconomyTune = TunePreset(
    id: 'aerox155_economy',
    name: 'Fuel Economy Tune',
    subtitle: 'Maximum fuel savings for highway commuting',
    category: PresetCategory.daily,
    ecuId: _ecuId,
    confidenceScore: 0.74,
    riskLevel: PresetRisk.safe,
    recommendedOctaneMin: 91,
    afrTargetExplanation:
        'Targets 14.0–14.6 AFR at cruise (lean of stock 13.8–14.4). '
        'VVA transition zone maintains stock enrichment — lean here risks knock. '
        'WOT kept at stock 12.5–13.0 for safety. '
        'Ignition advanced +1° at cruise for thermal efficiency.',
    benefits: [
      'Estimated 10–14% fuel consumption improvement at highway cruise',
      'Cooler exhaust temperature at light load',
      'Lower CO emissions',
    ],
    sideEffects: [
      'Reduced mid-range throttle response',
      'Not suitable for aggressive riding — AFR borderline lean at WOT',
      'Do not use with modified exhaust',
    ],
    warnings: [
      'Stock exhaust and air filter required — lean risk with modifications',
      'Do NOT ride aggressively with this tune — WOT enrichment is reduced',
      'Liquid-cooled engine means lean risk is lower than air-cooled, but still present',
    ],
    estimatedPowerGainPct: -3.0,
    estimatedFuelChangePct: -12.0,
    deltas: [
      // Lean cruise: 2000–5000 RPM × 20–60% TPS -5%
      MapZoneDelta(
        mapName: 'fuel_injection',
        rpmRowLow: 2, rpmRowHigh: 8,   // 2000–5000 RPM
        tpsColLow: 4, tpsColHigh: 8,   // 20–60% TPS
        percentDelta: -5.0,
      ),
      // Advance cruise ignition +1° for thermal efficiency
      MapZoneDelta(
        mapName: 'ignition_timing',
        rpmRowLow: 2, rpmRowHigh: 8,
        tpsColLow: 2, tpsColHigh: 7,
        absoluteDelta: 1.0,
      ),
      // Keep VVA zone stock (do NOT lean VVA transition — knock risk)
    ],
  );

  /// All Aerox 155 presets in display order.
  static const List<TunePreset> all = [
    vvaSmoothTune,
    dailyTune,
    aggressiveVvaTune,
    fuelEconomyTune,
    dragTune,
  ];
}
