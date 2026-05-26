/// AI tuning knowledge pack for the Yamaha Aerox 155 (Shindengen RH850 ECU).
///
/// All rules in this pack are specific to the Aerox 155 2020–2024 variant
/// with the stock Shindengen ECU. Never apply these rules to other ECU variants.
class Aerox155Pack {
  Aerox155Pack._();

  // ── ECU identity ──────────────────────────────────────────────────────────

  static const String ecuVariant = 'Shindengen RH850';
  static const String engineCc = '155cc';
  static const String coolingType = 'liquid-cooled';

  // ── Stock AFR targets ─────────────────────────────────────────────────────

  /// Stock cruise AFR range (light throttle, 2000–5500 RPM, pre-VVA).
  static const double stockAfrCruiseMin = 13.8;
  static const double stockAfrCruiseMax = 14.4;

  /// Stock WOT AFR target (full throttle, 7000+ RPM, post-VVA).
  static const double stockAfrWotMin = 12.5;
  static const double stockAfrWotMax = 13.0;

  /// AFR target during VVA transition (6000–7000 RPM transient).
  static const double vvaTransitionAfrMin = 13.0;
  static const double vvaTransitionAfrMax = 13.5;

  /// Absolute safe AFR floor — below this risks catalyst damage / rich stall.
  static const double absoluteAfrMin = 11.0;

  /// Absolute safe AFR ceiling — above this risks overheating (liquid-cooled
  /// gives more headroom than air-cooled but lean still causes knock).
  static const double absoluteAfrMax = 15.8;

  // ── VVA (Variable Valve Actuation) ───────────────────────────────────────

  /// RPM at which stock ECU commands VVA-ON (cam lobe switches to high-lift).
  static const int vvaEngageRpm = 6000;

  /// RPM at which stock ECU commands VVA-OFF on decel.
  static const int vvaDisengageRpm = 5800;

  /// TPS threshold above which VVA engages at vvaEngageRpm (%).
  static const int vvaEngageTpsMin = 30;

  /// VVA transition window: fuel enrichment required to prevent lean spike.
  static const int vvaTransitionWindowMs = 200;

  // ── Ignition timing ───────────────────────────────────────────────────────

  /// Base ignition advance at idle (1000–2000 RPM).
  static const double baseTimingIdleBtdc = 12.0;

  /// Base ignition advance at cruise (2000–6000 RPM, pre-VVA).
  static const double baseTimingCruiseBtdc = 32.0;

  /// Base ignition advance at high RPM (6000–10500, post-VVA).
  static const double baseTimingHighRpmBtdc = 36.0;

  /// Maximum absolute timing advance allowed at any RPM/load.
  static const double maxTimingBtdc = 40.0;

  /// Maximum safe timing advance over stock for pump fuel (91–95 RON).
  static const double safeAdvancePumpFuel = 2.0;

  /// Maximum safe timing advance over stock for premium fuel (97+ RON).
  static const double safeAdvancePremiumFuel = 4.0;

  /// Knock-retard step — ECU pulls this many degrees per knock event detected.
  static const double knockRetardStepDeg = 2.0;

  // ── Injector characteristics ──────────────────────────────────────────────

  /// Stock injector flow rate (cc/min at 3 bar rail pressure).
  static const double injectorFlowCcMin = 120.0;

  /// Injector dead time at 12.0V battery.
  static const double injectorDeadTimeMs = 0.75;

  // ── Rev limits ────────────────────────────────────────────────────────────

  static const int stockRevLimitRpm = 10500;

  /// Maximum safe rev limit for stock internals (forged piston, stock rod).
  static const int maxSafeRevLimit = 11000;

  // ── Knock sensitivity ─────────────────────────────────────────────────────

  /// RPM range where knock sensor is most active (high-compression zone).
  static const int knockSensitiveRpmLow = 5500;
  static const int knockSensitiveRpmHigh = 9000;

  /// TPS threshold above which knock risk is elevated (%).
  static const int knockElevatedTpsMin = 70;

  // ── Known lean zones ─────────────────────────────────────────────────────

  /// VVA engagement lean spike: ECU doesn't pre-enrich for the cam switch.
  /// Identified from wideband data across multiple Aerox 155 units in PH.
  static const int vvaLeanZoneRpmLow = 5800;
  static const int vvaLeanZoneRpmHigh = 6500;

  /// TPS range where VVA lean zone is significant.
  static const int vvaLeanZoneTpsLow = 40;
  static const int vvaLeanZoneTpsHigh = 100;

  /// Recommended enrichment at VVA transition to prevent lean spike.
  static const double vvaTransitionEnrichmentPercent = 6.0;

  // ── Common modification scenarios ─────────────────────────────────────────

  static const List<AeroxModScenario> knownModScenarios = [
    AeroxModScenario(
      modName: 'Free-flow exhaust (slip-on or full system)',
      afrEffect: 'Lean 6–10% in mid-range, VVA lean spike worsens',
      recommendedAction:
          'Enrich fuel map 6–10% in 4000–7000 RPM × 30–80% TPS. '
          'Pay special attention to 5800–6500 RPM VVA transition — '
          'add extra 8–12% here to counter combined VVA + exhaust lean.',
    ),
    AeroxModScenario(
      modName: 'Open air filter / pod filter',
      afrEffect: 'Lean at high-TPS, especially post-VVA',
      recommendedAction:
          'Enrich fuel 5–8% above 70% TPS across all RPM. '
          'Keep idle and low-TPS cells near stock. '
          'Monitor knock events — lean + pod filter raises knock risk at high RPM.',
    ),
    AeroxModScenario(
      modName: 'Bore-up kit (155→200cc)',
      afrEffect: 'Full re-baseline required — displacement change invalidates all maps',
      recommendedAction:
          'New fuel map baseline required. Scale injector pulse width by '
          '(new_cc / 155) as starting point only. '
          'Dyno tune mandatory. Knock sensor recalibration needed. '
          'VVA engagement RPM may need lowering to 5000–5500 RPM for larger bore.',
    ),
    AeroxModScenario(
      modName: 'High-compression piston (stock bore)',
      afrEffect: 'Increased knock risk, timing must be conservative',
      recommendedAction:
          'Retard ignition 2–3° in 5500–9000 RPM × 70–100% TPS zone. '
          'Use 97+ RON fuel only. Do NOT advance timing over stock. '
          'Monitor knock events closely for first 500 km.',
    ),
    AeroxModScenario(
      modName: 'VVA solenoid delete / fixed high-cam',
      afrEffect: 'VVA map becomes non-functional; high-cam at all RPM',
      recommendedAction:
          'Remove VVA transition enrichment — no longer needed. '
          'Advance timing 1–2° below 5000 RPM for better idle/cruise. '
          'Increase idle fuel 3–5% — high-lift cam reduces idle vacuum. '
          'NOT recommended for street use; primarily race/track only.',
    ),
  ];

  // ── System prompt builder for Claude API ─────────────────────────────────

  /// Build the system prompt to send to the Claude API for Aerox 155 tuning.
  static String buildSystemPrompt() {
    return '''
You are a professional motorcycle ECU tuning assistant specializing in the Yamaha Aerox 155
with the Shindengen RH850 ECU (liquid-cooled, VVA-equipped 155cc engine).

IMPORTANT RULES — NEVER VIOLATE:
1. AFR must stay between $absoluteAfrMin and $absoluteAfrMax at ALL times.
2. Ignition timing must never exceed $maxTimingBtdc° BTDC at any RPM or load.
3. For pump fuel (91–95 RON) max timing advance: +$safeAdvancePumpFuel° over stock.
4. For premium fuel (97+ RON) max timing advance: +$safeAdvancePremiumFuel° over stock.
5. Rev limit must not exceed $maxSafeRevLimit RPM on stock internals.
6. In the knock-sensitive zone ($knockSensitiveRpmLow–$knockSensitiveRpmHigh RPM, $knockElevatedTpsMin%+ TPS):
   timing suggestions must be conservative — err toward retard, not advance.
7. Never adjust VVA control solenoid duty cycle — VVA electrical mapping is hardware-locked.
8. Every suggestion must include: specific cells to change, magnitude, and revert instructions.

VVA SYSTEM AWARENESS:
- VVA engages at $vvaEngageRpm RPM (above $vvaEngageTpsMin% TPS) — cam switches to high-lift profile.
- VVA disengages at $vvaDisengageRpm RPM on decel.
- The $vvaLeanZoneRpmLow–$vvaLeanZoneRpmHigh RPM transition window is the most critical zone —
  lean spikes here cause knock and power dip. Always prioritize this zone in any fuel tune.
- VVA transition enrichment: $vvaTransitionEnrichmentPercent% minimum over neighboring cells.

STOCK BEHAVIOR:
- Cruise AFR (pre-VVA): $stockAfrCruiseMin–$stockAfrCruiseMax
- WOT AFR (post-VVA): $stockAfrWotMin–$stockAfrWotMax
- VVA transition AFR target: $vvaTransitionAfrMin–$vvaTransitionAfrMax
- Base timing idle: $baseTimingIdleBtdc° BTDC
- Base timing cruise: $baseTimingCruiseBtdc° BTDC
- Base timing high-RPM: $baseTimingHighRpmBtdc° BTDC
- Injector: $injectorFlowCcMin cc/min @ 3 bar, deadtime $injectorDeadTimeMs ms @ 12V
- Knock retard step: $knockRetardStepDeg° per event

RESPONSE FORMAT (always):
- Specific map cells to change (row/col or RPM×TPS zone)
- Exact new value or percentage change
- Reasoning (what symptom this addresses)
- Risk level: LOW / MEDIUM / HIGH
- VVA impact: note any effect on VVA transition behavior
- Revert: original values to restore if needed
''';
  }
}

class AeroxModScenario {
  final String modName;
  final String afrEffect;
  final String recommendedAction;

  const AeroxModScenario({
    required this.modName,
    required this.afrEffect,
    required this.recommendedAction,
  });
}
