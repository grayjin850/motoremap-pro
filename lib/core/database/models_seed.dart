import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Seeds all pre-populated motorcycle models and tune profiles into the DB
/// on first launch. Values represent Safe Reference Ranges — recommended
/// tuning targets, not proprietary ECU data.
class ModelsSeed {
  ModelsSeed._();

  // ---------------------------------------------------------------------------
  // Ignition map generator
  // RPM cols (12): 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 11000, 12000
  // TPS rows (12): 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 100
  // Timing: 15° at idle rising to [peakTiming]° at peak RPM
  // ---------------------------------------------------------------------------
  static String _buildIgnitionMapJson(int peakTiming) {
    final tpsRows = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 100];
    final rpmCols = [
      1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 11000, 12000
    ];

    final map = <List<double>>[];
    for (final tps in tpsRows) {
      final row = <double>[];
      for (int ci = 0; ci < rpmCols.length; ci++) {
        final rpmFraction = ci / (rpmCols.length - 1); // 0.0 – 1.0
        final tpsFraction = tps / 100.0;
        // Linear interpolation: 15° at idle → peakTiming at max RPM,
        // scaled slightly lower at partial throttle
        final base = 15.0 + (peakTiming - 15.0) * rpmFraction;
        final scaled = base * (0.7 + 0.3 * tpsFraction);
        row.add(double.parse(scaled.toStringAsFixed(1)));
      }
      map.add(row);
    }
    return jsonEncode(map);
  }

  // ---------------------------------------------------------------------------
  // Fuel map generator (AFR target map)
  // Rows: TPS (0–100 in 12 steps), Cols: RPM (idle to redline in 12 steps)
  // ---------------------------------------------------------------------------
  static String _buildFuelMapJson({
    required double afrMid,
    required double afrWot,
    bool hasVva = false,
    int vvaTransitionRpm = 0,
    int stockRevLimitSoft = 8000,
  }) {
    final tpsRows = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 100];
    // Distribute 12 RPM columns evenly from 1000 to stockRevLimitSoft
    final rpmStep = ((stockRevLimitSoft - 1000) / 11).round();
    final rpmCols = List.generate(12, (i) => 1000 + i * rpmStep);

    final map = <List<double>>[];
    for (final tps in tpsRows) {
      final row = <double>[];
      for (int ci = 0; ci < rpmCols.length; ci++) {
        final rpm = rpmCols[ci];
        final tpsFraction = tps / 100.0;
        // Interpolate AFR: at 0% TPS use afrMid+0.1 (slightly richer idle),
        // at 100% TPS (WOT) use afrWot
        double afr = afrMid + 0.1 + (afrWot - afrMid - 0.1) * tpsFraction;

        // VVA transition zone: conservative (slightly richer)
        if (hasVva && vvaTransitionRpm > 0) {
          if ((rpm - vvaTransitionRpm).abs() <= 500) {
            afr = (afr - 0.05).clamp(afrWot - 0.1, afrMid + 0.15);
          }
        }

        row.add(double.parse(afr.toStringAsFixed(2)));
      }
      map.add(row);
    }
    return jsonEncode(map);
  }

  // ---------------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------------

  static Future<void> seedAll(Database db) async {
    await _seedMotorcycles(db);
    await _seedAerox155Profiles(db);
  }

  // ---------------------------------------------------------------------------
  // Motorcycle seeds
  // ---------------------------------------------------------------------------

  static Future<void> _seedMotorcycles(Database db) async {
    final bikes = <Map<String, dynamic>>[
      // 1. Yamaha Aerox 155 VVA
      {
        'id': 'yamaha_aerox155_vva_2017',
        'brand': 'Yamaha',
        'model': 'Aerox 155 VVA',
        'year_from': 2017,
        'year_to': 0,
        'variant': 'VVA',
        'displacement': 155,
        'compression_ratio': 11.6,
        'bore': 58.0,
        'stroke': 58.7,
        'valve_system': 'SOHC',
        'valve_count': 4,
        'has_vva': 1,
        'vva_transition_rpm': 6000,
        'cooling': 'liquid',
        'ecu_type': 'Shindengen RH850',
        'flash_tool': 'Backdoor Module + Renesas',
        'stock_rev_limit_soft': 8500,
        'stock_rev_limit_hard': 9000,
        'stock_speed_limit': 120,
        'safe_afr_mid': 13.3,
        'safe_afr_wot': 13.0,
        'safe_afr_min': 12.8,
        'safe_afr_max': 13.5,
        'max_safe_rev_raise': 9500,
        'knock_rpm_zones': '4500,5000,5500',
        'expected_speed_by_level': '1:142.0,2:148.0,3:152.0,4:158.0',
      },
      // 2. Yamaha NMAX 155
      {
        'id': 'yamaha_nmax155_vva_2021',
        'brand': 'Yamaha',
        'model': 'NMAX 155',
        'year_from': 2021,
        'year_to': 0,
        'variant': 'VVA',
        'displacement': 155,
        'compression_ratio': 10.5,
        'bore': 58.0,
        'stroke': 58.7,
        'valve_system': 'SOHC',
        'valve_count': 4,
        'has_vva': 1,
        'vva_transition_rpm': 6000,
        'cooling': 'liquid',
        'ecu_type': 'Shindengen RH850',
        'flash_tool': 'Backdoor Module + Renesas',
        'stock_rev_limit_soft': 8000,
        'stock_rev_limit_hard': 8500,
        'stock_speed_limit': 115,
        'safe_afr_mid': 13.4,
        'safe_afr_wot': 13.1,
        'safe_afr_min': 13.0,
        'safe_afr_max': 13.6,
        'max_safe_rev_raise': 9000,
        'knock_rpm_zones': '',
        'expected_speed_by_level': '1:136.0,2:142.0,3:146.0,4:150.0',
      },
      // 3. Yamaha MT-15
      {
        'id': 'yamaha_mt15_vva_2019',
        'brand': 'Yamaha',
        'model': 'MT-15',
        'year_from': 2019,
        'year_to': 0,
        'variant': 'VVA',
        'displacement': 155,
        'compression_ratio': 11.6,
        'bore': 58.0,
        'stroke': 58.7,
        'valve_system': 'SOHC',
        'valve_count': 4,
        'has_vva': 1,
        'vva_transition_rpm': 6000,
        'cooling': 'liquid',
        'ecu_type': 'Shindengen RH850',
        'flash_tool': 'Backdoor Module + Renesas',
        'stock_rev_limit_soft': 10000,
        'stock_rev_limit_hard': 10500,
        'stock_speed_limit': 125,
        'safe_afr_mid': 13.3,
        'safe_afr_wot': 13.0,
        'safe_afr_min': 12.8,
        'safe_afr_max': 13.5,
        'max_safe_rev_raise': 11000,
        'knock_rpm_zones': '4500,5000',
        'expected_speed_by_level': '1:151.0,2:157.0,3:162.0,4:168.0',
      },
      // 4. Honda CBR150R
      {
        'id': 'honda_cbr150r_std_2016',
        'brand': 'Honda',
        'model': 'CBR150R',
        'year_from': 2016,
        'year_to': 0,
        'variant': 'Standard',
        'displacement': 149,
        'compression_ratio': 11.3,
        'bore': 57.3,
        'stroke': 57.8,
        'valve_system': 'DOHC',
        'valve_count': 4,
        'has_vva': 0,
        'vva_transition_rpm': 0,
        'cooling': 'liquid',
        'ecu_type': 'Keihin',
        'flash_tool': 'HRC Flash Tool / Generic Honda Tuner',
        'stock_rev_limit_soft': 10500,
        'stock_rev_limit_hard': 11000,
        'stock_speed_limit': 130,
        'safe_afr_mid': 13.2,
        'safe_afr_wot': 12.9,
        'safe_afr_min': 12.8,
        'safe_afr_max': 13.5,
        'max_safe_rev_raise': 11500,
        'knock_rpm_zones': '',
        'expected_speed_by_level': '1:151.0,2:157.0,3:162.0,4:167.0',
      },
      // 5. Honda CB150R
      {
        'id': 'honda_cb150r_std_2019',
        'brand': 'Honda',
        'model': 'CB150R',
        'year_from': 2019,
        'year_to': 0,
        'variant': 'Standard',
        'displacement': 149,
        'compression_ratio': 10.7,
        'bore': 57.3,
        'stroke': 57.8,
        'valve_system': 'DOHC',
        'valve_count': 4,
        'has_vva': 0,
        'vva_transition_rpm': 0,
        'cooling': 'liquid',
        'ecu_type': 'Keihin',
        'flash_tool': 'HRC Flash Tool / Generic Honda Tuner',
        'stock_rev_limit_soft': 10000,
        'stock_rev_limit_hard': 10500,
        'stock_speed_limit': 125,
        'safe_afr_mid': 13.4,
        'safe_afr_wot': 13.1,
        'safe_afr_min': 13.0,
        'safe_afr_max': 13.6,
        'max_safe_rev_raise': 11000,
        'knock_rpm_zones': '',
        'expected_speed_by_level': '1:138.0,2:144.0,3:149.0,4:154.0',
      },
      // 6. Honda Click 125i
      {
        'id': 'honda_click125i_std_2021',
        'brand': 'Honda',
        'model': 'Click 125i',
        'year_from': 2021,
        'year_to': 0,
        'variant': 'Standard',
        'displacement': 124,
        'compression_ratio': 11.0,
        'bore': 52.4,
        'stroke': 57.9,
        'valve_system': 'SOHC',
        'valve_count': 2,
        'has_vva': 0,
        'vva_transition_rpm': 0,
        'cooling': 'air',
        'ecu_type': 'Keihin',
        'flash_tool': 'Generic Honda Tuner',
        'stock_rev_limit_soft': 8500,
        'stock_rev_limit_hard': 9000,
        'stock_speed_limit': 110,
        'safe_afr_mid': 13.5,
        'safe_afr_wot': 13.1,
        'safe_afr_min': 13.0,
        'safe_afr_max': 13.7,
        'max_safe_rev_raise': 9500,
        'knock_rpm_zones': '',
        'expected_speed_by_level': '1:122.0,2:128.0,3:132.0,4:136.0',
      },
      // 7. Yamaha R3
      {
        'id': 'yamaha_r3_std_2019',
        'brand': 'Yamaha',
        'model': 'R3',
        'year_from': 2019,
        'year_to': 0,
        'variant': 'Standard',
        'displacement': 321,
        'compression_ratio': 11.2,
        'bore': 68.0,
        'stroke': 44.1,
        'valve_system': 'DOHC',
        'valve_count': 4,
        'has_vva': 0,
        'vva_transition_rpm': 0,
        'cooling': 'liquid',
        'ecu_type': 'Shindengen',
        'flash_tool': 'ECU Flash Tool + Renesas',
        'stock_rev_limit_soft': 12000,
        'stock_rev_limit_hard': 12500,
        'stock_speed_limit': 160,
        'safe_afr_mid': 13.2,
        'safe_afr_wot': 12.8,
        'safe_afr_min': 12.7,
        'safe_afr_max': 13.4,
        'max_safe_rev_raise': 13000,
        'knock_rpm_zones': '',
        'expected_speed_by_level': '1:178.0,2:184.0,3:189.0,4:195.0',
      },
    ];

    // Add generated fuel & ignition maps to each record (stored for reference,
    // not used in motorcycles table directly — kept in profiles)
    for (final bike in bikes) {
      await db.insert(
        'motorcycles',
        bike,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Aerox 155 VVA — 5 tune profiles
  // ---------------------------------------------------------------------------

  static Future<void> _seedAerox155Profiles(Database db) async {
    const aeroxId = 'yamaha_aerox155_vva_2017';

    // Shared ignition map for Aerox (compressionRatio 11.6 → maxTimingAdvance 3°)
    // Base peak timing for stock map around 30° advanced to 33° max
    final ignitionBase = _buildIgnitionMapJson(30);
    final ignitionPlus2 = _buildIgnitionMapJson(32);
    final ignitionPlus3 = _buildIgnitionMapJson(33);
    final ignitionPlus1 = _buildIgnitionMapJson(31);
    final ignitionEco = _buildIgnitionMapJson(28);

    final profiles = <Map<String, dynamic>>[
      // Profile 1: Top Speed
      {
        'id': 'aerox155_profile_topspeed',
        'motorcycle_model_id': aeroxId,
        'type': 'topSpeed',
        'name_taglish': 'Top Speed / Max Bilis',
        'description_taglish':
            'Para sa maximum na bilis sa highway. Mas mataas na rev limit, '
                'tinanggal ang speed limiter, at WOT AFR na optimized para sa power. '
                'Hindi para sa araw-araw na byahe sa lungsod.',
        'afr_target_mid': 13.2,
        'afr_target_wot': 13.0,
        'timing_advance_deg': 3,
        'rev_limit_raise': 1000,
        'remove_speed_limiter': 1,
        'safety_score': 88,
        'expected_benefits':
            'Est. +8–10 km/h top speed gain; improved high-RPM pull; '
                'removal of stock 120 km/h speed limiter',
        'fuel_consumption_note':
            'Mas mataas ang fuel consumption. Gamitin lamang ng premium fuel (RON95+).',
        'fuel_map_json': _buildFuelMapJson(
          afrMid: 13.2,
          afrWot: 13.0,
          hasVva: true,
          vvaTransitionRpm: 6000,
          stockRevLimitSoft: 9500,
        ),
        'ignition_map_json': ignitionPlus3,
      },
      // Profile 2: City Response
      {
        'id': 'aerox155_profile_cityresponse',
        'motorcycle_model_id': aeroxId,
        'type': 'cityResponse',
        'name_taglish': 'City Response / Pasok sa Lungsod',
        'description_taglish':
            'Mas mabilis na throttle response para sa stop-and-go traffic. '
                'Richer mid-range AFR para sa mas mabilis na pull mula 0–60 km/h. '
                'Pinapanatili ang stock rev at speed limits para sa kaligtasan.',
        'afr_target_mid': 13.5,
        'afr_target_wot': 13.2,
        'timing_advance_deg': 2,
        'rev_limit_raise': 0,
        'remove_speed_limiter': 0,
        'safety_score': 94,
        'expected_benefits':
            'Sharper 0–60 km/h pull; better throttle response in traffic; '
                'smoother VVA transition at 6000 RPM',
        'fuel_consumption_note':
            'Bahagyang mas mataas ang fuel use pero acceptable para sa city riding.',
        'fuel_map_json': _buildFuelMapJson(
          afrMid: 13.5,
          afrWot: 13.2,
          hasVva: true,
          vvaTransitionRpm: 6000,
          stockRevLimitSoft: 8500,
        ),
        'ignition_map_json': ignitionPlus2,
      },
      // Profile 3: Handling
      {
        'id': 'aerox155_profile_handling',
        'motorcycle_model_id': aeroxId,
        'type': 'handling',
        'name_taglish': 'Handling / Kontrolado',
        'description_taglish':
            'Consistent na AFR sa lahat ng RPM para sa predictable at smooth na '
                'throttle response. Ideal para sa twisty roads o track days. '
                'Minimum na safety margin, walang rev at speed limit changes.',
        'afr_target_mid': 13.5,
        'afr_target_wot': 13.5,
        'timing_advance_deg': 1,
        'rev_limit_raise': 0,
        'remove_speed_limiter': 0,
        'safety_score': 96,
        'expected_benefits':
            'Predictable throttle response; smooth power delivery; '
                'reduced engine stumble on corner entry/exit',
        'fuel_consumption_note':
            'Katulad ng stock fuel consumption dahil consistent na AFR.',
        'fuel_map_json': _buildFuelMapJson(
          afrMid: 13.5,
          afrWot: 13.5,
          hasVva: true,
          vvaTransitionRpm: 6000,
          stockRevLimitSoft: 8500,
        ),
        'ignition_map_json': ignitionPlus1,
      },
      // Profile 4: Balanced
      {
        'id': 'aerox155_profile_balanced',
        'motorcycle_model_id': aeroxId,
        'type': 'balanced',
        'name_taglish': 'Balanced / Balanseng Setup',
        'description_taglish':
            'Pinagsama ang city response at light top-speed gains. '
                'Mid AFR para sa daily use, slight WOT enrichment para sa highway, '
                'at +500 RPM raise para sa mas maayos na pull bago mag-rev cut. '
                'Tinanggal ang speed limiter para sa highway safety.',
        'afr_target_mid': 13.3,
        'afr_target_wot': 13.0,
        'timing_advance_deg': 2,
        'rev_limit_raise': 500,
        'remove_speed_limiter': 1,
        'safety_score': 91,
        'expected_benefits':
            'Best all-around daily profile; +4–6 km/h top end; '
                'improved mid-range; suitable for highway and city',
        'fuel_consumption_note':
            'Bahagyang mas mataas — mga 5–8% — pero acceptable para sa balanced use.',
        'fuel_map_json': _buildFuelMapJson(
          afrMid: 13.3,
          afrWot: 13.0,
          hasVva: true,
          vvaTransitionRpm: 6000,
          stockRevLimitSoft: 9000,
        ),
        'ignition_map_json': ignitionPlus2,
      },
      // Profile 5: Eco
      {
        'id': 'aerox155_profile_eco',
        'motorcycle_model_id': aeroxId,
        'type': 'eco',
        'name_taglish': 'Eco / Tipid sa Gasolina',
        'description_taglish':
            'Lean AFR sa light throttle para sa pinakamababang fuel consumption. '
                'Para sa commuters na gusto ng mas matagal na hatid ng isang litrong gasolina. '
                'Stock rev at speed limits. Hindi para sa highway at mabilis na pagmamaneho.',
        'afr_target_mid': 14.2,
        'afr_target_wot': 14.0,
        'timing_advance_deg': 0,
        'rev_limit_raise': 0,
        'remove_speed_limiter': 0,
        'safety_score': 98,
        'expected_benefits':
            'Est. 15–20% better fuel economy at light throttle; '
                'ideal for low-speed commuting under 80 km/h',
        'fuel_consumption_note':
            'Pinakamababang fuel use — ang layunin ng profile na ito. '
                'Huwag itong gamitin sa highway o WOT — lean AFR ay mapanganib sa mataas na RPM.',
        'fuel_map_json': _buildFuelMapJson(
          afrMid: 14.2,
          afrWot: 14.0,
          hasVva: true,
          vvaTransitionRpm: 6000,
          stockRevLimitSoft: 8500,
        ),
        'ignition_map_json': ignitionEco,
      },
    ];

    // Suppress unused variable warning — ignitionBase is a fallback reference
    // that may be used in future profiles
    final _ = ignitionBase;

    for (final profile in profiles) {
      await db.insert(
        'tune_profiles',
        profile,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
