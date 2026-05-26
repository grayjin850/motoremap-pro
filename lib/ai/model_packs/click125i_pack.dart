/// AI tuning knowledge pack for the Honda Click 125i (Keihin PGM-FI).
///
/// All rules in this pack are specific to the Click 125i 2014–2021 variant
/// with the stock Keihin ECU. Never apply these rules to other ECU variants.
class Click125iPack {
  Click125iPack._();

  // ── ECU identity ──────────────────────────────────────────────────────────

  static const String ecuPart = '37820-KYZ';
  static const String engineCc = '125cc';
  static const String coolingType = 'air-cooled';

  // ── Stock AFR targets ─────────────────────────────────────────────────────

  /// Stock cruise AFR range (light throttle, 2500–5000 RPM).
  static const double stockAfrCruiseMin = 13.5;
  static const double stockAfrCruiseMax = 14.2;

  /// Stock WOT AFR target (full throttle, 5000+ RPM).
  static const double stockAfrWot = 13.0;

  /// Absolute safe AFR floor — below this risks piston damage.
  static const double absoluteAfrMin = 11.5;

  /// Absolute safe AFR ceiling — above this risks overheating.
  static const double absoluteAfrMax = 15.5;

  // ── Ignition timing ───────────────────────────────────────────────────────

  /// Base ignition advance (BTDC) at idle/cruise.
  static const double baseTimingBtdc = 28.0;

  /// Maximum timing advance at any condition (stock ECU limit).
  static const double maxTimingBtdc = 35.0;

  /// Maximum safe timing advance for 91–95 RON pump fuel.
  static const double safeAdvancePumpFuel = 3.0;

  /// Maximum safe timing advance for 97+ RON premium fuel.
  static const double safeAdvancePremiumFuel = 5.0;

  // ── Injector characteristics ──────────────────────────────────────────────

  /// Stock injector flow rate (cc/min at 3 bar rail pressure).
  static const double injectorFlowCcMin = 90.0;

  /// Injector dead time at 12.0V battery.
  static const double injectorDeadTimeMs = 0.8;

  // ── Rev limits ────────────────────────────────────────────────────────────

  static const int stockRevLimitRpm = 8500;

  /// Maximum safe rev limit raise for stock internals.
  static const int maxSafeRevLimit = 9000;

  // ── Known lean zones ─────────────────────────────────────────────────────

  /// RPM range known to run lean in stock map (common with free-flow exhaust).
  /// Identified from dyno data across multiple Click 125i units in PH.
  static const int leanZoneRpmLow = 3000;
  static const int leanZoneRpmHigh = 4500;

  /// TPS% range of the lean zone.
  static const int leanZoneTpsLow = 20;
  static const int leanZoneTpsHigh = 60;

  /// Recommended enrichment for free-flow exhaust in the lean zone.
  static const double freeFlowEnrichmentPercent = 10.0;

  // ── Common modification scenarios ─────────────────────────────────────────

  static const List<ClickModScenario> knownModScenarios = [
    ClickModScenario(
      modName: 'Free-flow exhaust (open-pipe or slip-on)',
      afrEffect: 'Lean by ~8–12% across mid-range',
      recommendedAction:
          'Enrich fuel map 8–12% in 3000–4500 RPM × 20–60% TPS zone. '
          'Monitor AFR post-flash; target 13.2–13.8 cruise.',
    ),
    ClickModScenario(
      modName: 'Open air filter / pod filter',
      afrEffect: 'Lean at high-TPS, may richen slightly at idle',
      recommendedAction:
          'Enrich fuel 5–8% above 60% TPS. '
          'Keep idle and low-TPS cells near stock.',
    ),
    ClickModScenario(
      modName: 'Stage 1 cam upgrade (Daytona / TDR)',
      afrEffect: 'Full re-baseline required — stock map invalid',
      recommendedAction:
          'Start from scratch with cam-specific fuel + timing base. '
          'Dyno tune recommended. Air-cooled engine limits timing advance to +2° max.',
    ),
  ];

  // ── System prompt builder for Claude API ─────────────────────────────────

  /// Build the system prompt to send to the Claude API for Click 125i tuning.
  static String buildSystemPrompt() {
    return '''
You are a professional motorcycle ECU tuning assistant specializing in the Honda Click 125i
with the Keihin PGM-FI ECU (part number: $ecuPart).

IMPORTANT RULES — NEVER VIOLATE:
1. AFR must stay between $absoluteAfrMin and $absoluteAfrMax at ALL times.
2. Ignition timing must never exceed $maxTimingBtdc° BTDC.
3. For pump fuel (91–95 RON) max timing advance: +$safeAdvancePumpFuel° over stock.
4. For premium fuel (97+ RON) max timing advance: +$safeAdvancePremiumFuel° over stock.
5. Rev limit must not exceed $maxSafeRevLimit RPM on stock internals.
6. Never suggest changes outside the known safe map offsets.
7. Every suggestion must include: specific cells to change, magnitude, and revert instructions.

STOCK BEHAVIOR:
- Cruise AFR: $stockAfrCruiseMin–$stockAfrCruiseMax
- WOT AFR target: $stockAfrWot
- Known lean zone: $leanZoneRpmLow–$leanZoneRpmHigh RPM × $leanZoneTpsLow–$leanZoneTpsHigh% TPS
- Base timing: $baseTimingBtdc° BTDC
- Injector: $injectorFlowCcMin cc/min @ 3 bar, deadtime $injectorDeadTimeMs ms @ 12V

RESPONSE FORMAT (always):
- Specific map cells to change (row/col or RPM×TPS zone)
- Exact new value or percentage change
- Reasoning (what symptom this addresses)
- Risk level: LOW / MEDIUM / HIGH
- Revert: original values to restore if needed
''';
  }
}

class ClickModScenario {
  final String modName;
  final String afrEffect;
  final String recommendedAction;

  const ClickModScenario({
    required this.modName,
    required this.afrEffect,
    required this.recommendedAction,
  });
}
