import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Seeds all pre-populated motorcycle models and tune profiles.
/// Values represent Safe Reference Ranges — recommended tuning targets,
/// not proprietary ECU data.
class ModelsSeed {
  ModelsSeed._();

  // ---------------------------------------------------------------------------
  // Ignition map builder
  // RPM cols (12): 1000→redline in 12 even steps
  // TPS rows (12): 0,10,20,30,40,50,60,70,80,90,95,100
  // ---------------------------------------------------------------------------
  static String _buildIgnitionMapJson(int peakTiming) {
    const tpsRows = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 100];
    final map = <List<double>>[];
    for (final tps in tpsRows) {
      final row = <double>[];
      for (int ci = 0; ci < 12; ci++) {
        final rpmFraction = ci / 11;
        final tpsFraction = tps / 100.0;
        final base = 15.0 + (peakTiming - 15.0) * rpmFraction;
        final scaled = base * (0.7 + 0.3 * tpsFraction);
        row.add(double.parse(scaled.toStringAsFixed(1)));
      }
      map.add(row);
    }
    return jsonEncode(map);
  }

  // ---------------------------------------------------------------------------
  // Fuel map builder (AFR target map)
  // ---------------------------------------------------------------------------
  static String _buildFuelMapJson({
    required double afrMid,
    required double afrWot,
    bool hasVva = false,
    int vvaTransitionRpm = 0,
    int stockRevLimitSoft = 8000,
  }) {
    const tpsRows = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 100];
    final rpmStep = ((stockRevLimitSoft - 1000) / 11).round();
    final rpmCols = List.generate(12, (i) => 1000 + i * rpmStep);

    final map = <List<double>>[];
    for (final tps in tpsRows) {
      final row = <double>[];
      for (int ci = 0; ci < rpmCols.length; ci++) {
        final rpm = rpmCols[ci];
        final tpsFraction = tps / 100.0;
        double afr = afrMid + 0.1 + (afrWot - afrMid - 0.1) * tpsFraction;
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
  // Public entry points
  // ---------------------------------------------------------------------------

  static Future<void> seedAll(Database db) async {
    await _seedMotorcycles(db);
    await _seedAerox155Profiles(db);
    await _seedNmax155Profiles(db);
    await _seedMt15Profiles(db);
    await _seedCbr150rProfiles(db);
    await _seedCb150rProfiles(db);
    await _seedClick125iProfiles(db);
    await _seedR3Profiles(db);
  }

  /// Called on v1 → v2 DB migration to seed bikes that had no profiles in v1.
  static Future<void> seedAdditionalProfiles(Database db) async {
    await _seedNmax155Profiles(db);
    await _seedMt15Profiles(db);
    await _seedCbr150rProfiles(db);
    await _seedCb150rProfiles(db);
    await _seedClick125iProfiles(db);
    await _seedR3Profiles(db);
  }

  // ---------------------------------------------------------------------------
  // Motorcycle model seeds
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
        'ecu_type': 'Yamaha Y-ECU (Shindengen)',
        'flash_tool': 'Backdoor Module + Renesas',
        'stock_rev_limit_soft': 8500,
        'stock_rev_limit_hard': 9000,
        'stock_speed_limit': 120,
        'safe_afr_mid': 13.4,
        'safe_afr_wot': 13.0,
        'safe_afr_min': 12.9,
        'safe_afr_max': 14.3,
        'max_safe_rev_raise': 9500,
        'knock_rpm_zones': '5800,6200',
        'expected_speed_by_level': '1:128.0,2:134.0,3:139.0,4:144.0',
      },
      // 2. Yamaha Nmax 155 VVA
      {
        'id': 'yamaha_nmax155_vva_2020',
        'brand': 'Yamaha',
        'model': 'Nmax 155 VVA',
        'year_from': 2020,
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
        'stock_rev_limit_soft': 8000,
        'stock_rev_limit_hard': 8500,
        'stock_speed_limit': 115,
        'safe_afr_mid': 13.4,
        'safe_afr_wot': 13.1,
        'safe_afr_min': 13.0,
        'safe_afr_max': 14.2,
        'max_safe_rev_raise': 9000,
        'knock_rpm_zones': '',
        'expected_speed_by_level': '1:124.0,2:130.0,3:135.0,4:140.0',
      },
      // 3. Yamaha MT-15 VVA
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

    for (final bike in bikes) {
      await db.insert('motorcycles', bike,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // Helper to insert profiles with conflict ignore
  static Future<void> _insert(Database db, List<Map<String, dynamic>> profiles) async {
    for (final p in profiles) {
      await db.insert('tune_profiles', p,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ===========================================================================
  // 1. YAMAHA AEROX 155 VVA — 8 profiles
  // compressionRatio 11.6 → maxTimingAdvance +3°
  // ===========================================================================
  static Future<void> _seedAerox155Profiles(Database db) async {
    const id = 'yamaha_aerox155_vva_2017';
    await _insert(db, [
      {
        'id': 'aerox155_topspeed',
        'motorcycle_model_id': id,
        'type': 'topSpeed',
        'name_taglish': 'Top Speed — Max Bilis',
        'description_taglish':
            'Para sa maximum na bilis sa highway. Tinanggal ang speed limiter, '
            'max timing advance (+3°), at enriched WOT AFR para sa power.',
        'afr_target_mid': 13.2, 'afr_target_wot': 13.0,
        'timing_advance_deg': 3, 'rev_limit_raise': 1000, 'remove_speed_limiter': 1,
        'safety_score': 88,
        'expected_benefits': 'Est. +8–10 km/h; speed limiter deleted; max high-RPM pull',
        'fuel_consumption_note': 'Gumagamit ng RON95+. Mas mataas na fuel use.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.2, afrWot: 13.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 9500),
        'ignition_map_json': _buildIgnitionMapJson(33),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'aerox155_balanced',
        'motorcycle_model_id': id,
        'type': 'balanced',
        'name_taglish': 'Balanced — Para sa Lahat',
        'description_taglish':
            'Best all-around profile. +500 RPM raise, tinanggal ang speed limiter, '
            'at smooth na VVA transition. Ideal para sa highway at lungsod.',
        'afr_target_mid': 13.3, 'afr_target_wot': 13.0,
        'timing_advance_deg': 2, 'rev_limit_raise': 500, 'remove_speed_limiter': 1,
        'safety_score': 91,
        'expected_benefits': '+4–6 km/h top end; smooth VVA zone; city at highway ready',
        'fuel_consumption_note': 'Bahagyang mas mataas — ~5–8% kumpara sa stock.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.3, afrWot: 13.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 9000),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'aerox155_cityresponse',
        'motorcycle_model_id': id,
        'type': 'cityResponse',
        'name_taglish': 'City Response — Bilis sa Traffic',
        'description_taglish':
            'Sharper throttle response para sa stop-and-go. Richer mid AFR '
            'para sa mas mabilis na pull mula 0–60 km/h.',
        'afr_target_mid': 13.5, 'afr_target_wot': 13.2,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 94,
        'expected_benefits': 'Mas mabilis na 0–60; smooth throttle sa traffic',
        'fuel_consumption_note': 'Bahagyang mas mataas pero acceptable.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.5, afrWot: 13.2, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'aerox155_eco',
        'motorcycle_model_id': id,
        'type': 'eco',
        'name_taglish': 'Eco — Tipid sa Gasolina',
        'description_taglish':
            'Lean AFR sa light throttle para sa pinakamababang fuel use. '
            'Para sa mga commuter na gusto ng matagal na hatid ng isang litro.',
        'afr_target_mid': 14.2, 'afr_target_wot': 14.0,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 98,
        'expected_benefits': 'Est. 15–20% better fuel economy sa light throttle',
        'fuel_consumption_note': 'Pinakamababang fuel use. Huwag gamitin sa WOT o highway.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 14.2, afrWot: 14.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(28),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'aerox155_vva_transition',
        'motorcycle_model_id': id,
        'type': 'vvaTransition',
        'name_taglish': 'VVA Smooth — Tanggalin ang VVA Stutter',
        'description_taglish':
            'Tinitibay ang fuel delivery sa paligid ng 6000 RPM VVA crossover point. '
            'Inaalis ang nauusong stutter o hesitation noong nagpapalit ng cam profile ang VVA.',
        'afr_target_mid': 13.4, 'afr_target_wot': 13.1,
        'timing_advance_deg': 1, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 96,
        'expected_benefits': 'Walang stutter sa 5800–6200 RPM; mas maayos na acceleration',
        'fuel_consumption_note': 'Halos katulad ng stock — minimal na pagbabago.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.4, afrWot: 13.1, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'aerox155_endurance',
        'motorcycle_model_id': id,
        'type': 'endurance',
        'name_taglish': 'Endurance — Para sa Mahabang Biyahe',
        'description_taglish':
            'Conservative timing, slightly rich cruise AFR, at stable power delivery '
            'para sa matagal na pagmamaneho. Mas malamig ang engine sa mga Expressway trips.',
        'afr_target_mid': 13.6, 'afr_target_wot': 13.2,
        'timing_advance_deg': 1, 'rev_limit_raise': 0, 'remove_speed_limiter': 1,
        'safety_score': 95,
        'expected_benefits': 'Mas malamig na engine sa highway; stable na power; kaya ang SLEX/NLEX trips',
        'fuel_consumption_note': 'Katulad ng stock — dinisenyo para sa sustainability.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.6, afrWot: 13.2, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(30),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'aerox155_cold_start',
        'motorcycle_model_id': id,
        'type': 'coldStart',
        'name_taglish': 'Cold Start Fix — Ayos sa Umaga',
        'description_taglish':
            'Nagdadagdag ng warmup enrichment para sa malamig na pagpapaandar. '
            'Inaabot ang idle quality at inaalis ang stalling habang nagpapalasa pa ang makina.',
        'afr_target_mid': 13.5, 'afr_target_wot': 13.1,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 99,
        'expected_benefits': 'Mas maayos na cold start; hindi mag-i-stall sa unang ilang minuto',
        'fuel_consumption_note': 'Minimal na epekto sa pangkalahatang fuel economy.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.5, afrWot: 13.1, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(30),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'aerox155_handling',
        'motorcycle_model_id': id,
        'type': 'handling',
        'name_taglish': 'Handling — Pantay na Power Delivery',
        'description_taglish':
            'Consistent na AFR sa lahat ng RPM para sa predictable at smooth na throttle. '
            'Ideal para sa twisty roads at gustong kontrolin ang acceleration.',
        'afr_target_mid': 13.5, 'afr_target_wot': 13.5,
        'timing_advance_deg': 1, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 96,
        'expected_benefits': 'Predictable throttle; walang power surge; smooth sa corners',
        'fuel_consumption_note': 'Katulad ng stock fuel consumption.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.5, afrWot: 13.5, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
    ]);
  }

  // ===========================================================================
  // 2. YAMAHA NMAX 155 VVA — 6 profiles (commuter scooter)
  // compressionRatio 11.6 → maxTimingAdvance +3°
  // ===========================================================================
  static Future<void> _seedNmax155Profiles(Database db) async {
    const id = 'yamaha_nmax155_vva_2020';
    await _insert(db, [
      {
        'id': 'nmax155_eco',
        'motorcycle_model_id': id,
        'type': 'eco',
        'name_taglish': 'Eco — Tipid sa Gasolina',
        'description_taglish':
            'Lean AFR para sa commuter na naghahanap ng pinakamahabang range. '
            'Perpekto para sa araw-araw na biyahe sa lungsod under 80 km/h.',
        'afr_target_mid': 14.2, 'afr_target_wot': 14.0,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 98,
        'expected_benefits': 'Est. 15–20% mas mahaba ang range; ideal para sa lungsod',
        'fuel_consumption_note': 'Pinaka-tipid na setup. Huwag gamitin sa WOT.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 14.2, afrWot: 14.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8000),
        'ignition_map_json': _buildIgnitionMapJson(28),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'nmax155_balanced',
        'motorcycle_model_id': id,
        'type': 'balanced',
        'name_taglish': 'Balanced — Pinakamainam na Setup',
        'description_taglish':
            'Pinaka-recommended na profile para sa Nmax 155. Binalanse ang city response at '
            'highway performance, tinanggal ang speed limiter, at smoothed ang VVA transition.',
        'afr_target_mid': 13.4, 'afr_target_wot': 13.1,
        'timing_advance_deg': 2, 'rev_limit_raise': 300, 'remove_speed_limiter': 1,
        'safety_score': 92,
        'expected_benefits': 'Pinakamainam para sa daily use; +3–5 km/h; smooth VVA zone',
        'fuel_consumption_note': 'Bahagyang mas mataas (~5%) kumpara sa stock.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.4, afrWot: 13.1, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8300),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'nmax155_vva_transition',
        'motorcycle_model_id': id,
        'type': 'vvaTransition',
        'name_taglish': 'VVA Smooth — Tanggalin ang Stutter',
        'description_taglish':
            'Tumutuon sa pag-aalis ng VVA stutter zone (5800–6200 RPM). '
            'Para sa mga Nmax na may naramdamang hesitation sa mid-range.',
        'afr_target_mid': 13.5, 'afr_target_wot': 13.2,
        'timing_advance_deg': 1, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 97,
        'expected_benefits': 'Walang hesitation sa VVA zone; mas maayos na mid-range',
        'fuel_consumption_note': 'Minimal na pagbabago sa fuel use.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.5, afrWot: 13.2, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8000),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'nmax155_endurance',
        'motorcycle_model_id': id,
        'type': 'endurance',
        'name_taglish': 'Endurance — Para sa EDSA at Expressway',
        'description_taglish':
            'Stable at malamig na engine sa mahabang biyahe. Conservative timing, '
            'slightly rich cruise AFR, walang speed limiter para sa expressway.',
        'afr_target_mid': 13.6, 'afr_target_wot': 13.3,
        'timing_advance_deg': 1, 'rev_limit_raise': 0, 'remove_speed_limiter': 1,
        'safety_score': 95,
        'expected_benefits': 'Mas malamig na engine; stable sa mabagal at mabilis na biyahe',
        'fuel_consumption_note': 'Halos katulad ng stock.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.6, afrWot: 13.3, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8000),
        'ignition_map_json': _buildIgnitionMapJson(30),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'nmax155_topspeed',
        'motorcycle_model_id': id,
        'type': 'topSpeed',
        'name_taglish': 'Top Speed — Speed Limiter Delete',
        'description_taglish':
            'Inaalis ang stock 115 km/h speed limiter at nagdadagdag ng maximum '
            'timing advance para sa maximum na top speed. Para sa highway use.',
        'afr_target_mid': 13.2, 'afr_target_wot': 13.0,
        'timing_advance_deg': 3, 'rev_limit_raise': 1000, 'remove_speed_limiter': 1,
        'safety_score': 87,
        'expected_benefits': 'Inaalis ang 115 km/h limiter; est. +8–10 km/h top speed',
        'fuel_consumption_note': 'Mas mataas na fuel use. Gamitin RON95.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.2, afrWot: 13.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 9000),
        'ignition_map_json': _buildIgnitionMapJson(33),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'nmax155_idle_quality',
        'motorcycle_model_id': id,
        'type': 'idleQuality',
        'name_taglish': 'Idle Fix — Ayusin ang Idle',
        'description_taglish':
            'Para sa mga Nmax na may mahinang idle, nag-i-stall sa traffic, '
            'o hindi maayos ang pagpatakbo sa malamig. Itinatama ang idle mixture.',
        'afr_target_mid': 13.8, 'afr_target_wot': 13.2,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 99,
        'expected_benefits': 'Stable idle; hindi mag-i-stall sa traffic; maayos na warm-up',
        'fuel_consumption_note': 'Walang epekto sa pangkalahatang fuel economy.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.8, afrWot: 13.2, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 8000),
        'ignition_map_json': _buildIgnitionMapJson(30),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
    ]);
  }

  // ===========================================================================
  // 3. YAMAHA MT-15 VVA — 6 profiles (sport naked)
  // compressionRatio 11.6 → maxTimingAdvance +3° | stock rev 10000
  // ===========================================================================
  static Future<void> _seedMt15Profiles(Database db) async {
    const id = 'yamaha_mt15_vva_2019';
    await _insert(db, [
      {
        'id': 'mt15_balanced',
        'motorcycle_model_id': id,
        'type': 'balanced',
        'name_taglish': 'Balanced — Para sa Daily at Weekend',
        'description_taglish':
            'All-around profile para sa MT-15. Nagdadagdag ng throttle response '
            'para sa city at kaunting top-end para sa highway.',
        'afr_target_mid': 13.2, 'afr_target_wot': 13.0,
        'timing_advance_deg': 2, 'rev_limit_raise': 500, 'remove_speed_limiter': 1,
        'safety_score': 91,
        'expected_benefits': 'Mas mabilis na throttle response; +4 km/h top; smooth na VVA zone',
        'fuel_consumption_note': 'Bahagyang mas mataas (~6%).',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.2, afrWot: 13.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 10500),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'mt15_topspeed',
        'motorcycle_model_id': id,
        'type': 'topSpeed',
        'name_taglish': 'Top Speed — Max Bilis at Rev',
        'description_taglish':
            'Para sa maximum na performance ng MT-15. Max timing advance, '
            '+1000 RPM rev raise, tinanggal ang speed limiter.',
        'afr_target_mid': 13.0, 'afr_target_wot': 12.9,
        'timing_advance_deg': 3, 'rev_limit_raise': 1000, 'remove_speed_limiter': 1,
        'safety_score': 85,
        'expected_benefits': 'Pinaka-aggressive na setup; mas mataas na top end at rev',
        'fuel_consumption_note': 'Kailangan ng RON95. Mas mataas ang fuel use.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.0, afrWot: 12.9, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 11000),
        'ignition_map_json': _buildIgnitionMapJson(33),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'mt15_vva_transition',
        'motorcycle_model_id': id,
        'type': 'vvaTransition',
        'name_taglish': 'VVA Smooth — Para sa Sport Riding',
        'description_taglish':
            'Pinaka-importante para sa MT-15 na ginagamit sa sport riding. '
            'Tinatanggal ang VVA stutter na maramdaman sa 6000 RPM upshift zone.',
        'afr_target_mid': 13.3, 'afr_target_wot': 13.0,
        'timing_advance_deg': 1, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 97,
        'expected_benefits': 'Smooth na power sa 5500–6500 RPM zone; no cam switch stutter',
        'fuel_consumption_note': 'Minimal na pagbabago.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.3, afrWot: 13.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 10000),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'mt15_throttle_sharp',
        'motorcycle_model_id': id,
        'type': 'throttleSharpening',
        'name_taglish': 'Throttle Sharp — Mabilis na Tugon',
        'description_taglish':
            'Mas matalas na TPS-to-fuel na mapping para sa mas snappy na pakiramdam '
            'ng MT-15 sa lungsod at twisty roads. Hindi nagbabago ng limiters.',
        'afr_target_mid': 13.2, 'afr_target_wot': 13.0,
        'timing_advance_deg': 1, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 93,
        'expected_benefits': 'Mas mabilis ang tugon sa unang 30% ng throttle; sporty na feeling',
        'fuel_consumption_note': 'Bahagyang mas mataas sa city dahil mas aggressive ang mapping.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.2, afrWot: 13.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 10000),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'mt15_decel_fuel_cut',
        'motorcycle_model_id': id,
        'type': 'decelFuelCut',
        'name_taglish': 'Anti-Pop — Ayusin ang Decel Backfire',
        'description_taglish':
            'Inaayos ang DFCO (Deceleration Fuel Cut Off) threshold. '
            'Para sa mga MT-15 na may maingay na decel pop o jerky engine braking.',
        'afr_target_mid': 13.4, 'afr_target_wot': 13.0,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 96,
        'expected_benefits': 'Wala nang decel pop/backfire; smoother na engine braking',
        'fuel_consumption_note': 'Minimal na epekto — medyo mas mataas sa DFCO zone.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.4, afrWot: 13.0, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 10000),
        'ignition_map_json': _buildIgnitionMapJson(30),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'mt15_handling',
        'motorcycle_model_id': id,
        'type': 'handling',
        'name_taglish': 'Handling — Para sa Track Days',
        'description_taglish':
            'Flat na AFR curve para sa consistent at predictable na power delivery. '
            'Perpekto para sa corner entry/exit na may precise na throttle.',
        'afr_target_mid': 13.3, 'afr_target_wot': 13.3,
        'timing_advance_deg': 1, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 95,
        'expected_benefits': 'Predictable power; no power surge mid-corner; smooth na feel',
        'fuel_consumption_note': 'Katulad ng stock.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.3, afrWot: 13.3, hasVva: true, vvaTransitionRpm: 6000, stockRevLimitSoft: 10000),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': 'vva', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
    ]);
  }

  // ===========================================================================
  // 4. HONDA CBR150R — 6 profiles (DOHC sportbike, no VVA)
  // compressionRatio 11.3 → maxTimingAdvance +4° | stock rev 10500
  // ===========================================================================
  static Future<void> _seedCbr150rProfiles(Database db) async {
    const id = 'honda_cbr150r_std_2016';
    await _insert(db, [
      {
        'id': 'cbr150r_balanced',
        'motorcycle_model_id': id,
        'type': 'balanced',
        'name_taglish': 'Balanced — Best Daily Setup',
        'description_taglish':
            'Pinaka-recommended para sa CBR150R. Nagdadagdag ng timing advance (+3°), '
            'enriched WOT, at tinanggal ang speed limiter para sa highway.',
        'afr_target_mid': 13.1, 'afr_target_wot': 12.9,
        'timing_advance_deg': 3, 'rev_limit_raise': 500, 'remove_speed_limiter': 1,
        'safety_score': 90,
        'expected_benefits': '+5–7% mid-range power; tinanggal ang 130 km/h limiter',
        'fuel_consumption_note': 'Bahagyang mas mataas (~7%). Gamit RON91 puwede, RON95 mas mainam.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.1, afrWot: 12.9, stockRevLimitSoft: 11000),
        'ignition_map_json': _buildIgnitionMapJson(33),
        'required_features': 'dohc', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'cbr150r_topspeed',
        'motorcycle_model_id': id,
        'type': 'topSpeed',
        'name_taglish': 'Top Speed — Max Timing at Rev',
        'description_taglish':
            'Maximum na timing advance (+4°, safety floor ng 11.3:1 compression), '
            '+1000 RPM raise, at WOT enrichment para sa pinakamataas na top speed.',
        'afr_target_mid': 13.0, 'afr_target_wot': 12.8,
        'timing_advance_deg': 4, 'rev_limit_raise': 1000, 'remove_speed_limiter': 1,
        'safety_score': 86,
        'expected_benefits': 'Pinaka-max na performance; est. +10–12 km/h top end',
        'fuel_consumption_note': 'Kailangan ng RON95. Mataas na fuel use sa WOT.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.0, afrWot: 12.8, stockRevLimitSoft: 11500),
        'ignition_map_json': _buildIgnitionMapJson(34),
        'required_features': 'dohc', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'cbr150r_throttle_sharp',
        'motorcycle_model_id': id,
        'type': 'throttleSharpening',
        'name_taglish': 'Throttle Sharp — Sporty na Feel',
        'description_taglish':
            'Steeper TPS-to-fuel mapping para sa mas immediate na response. '
            'Ang CBR150R ay kilala sa smooth na power — ito ay nagbibigay ng mas sporty na feel.',
        'afr_target_mid': 13.1, 'afr_target_wot': 12.9,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 93,
        'expected_benefits': 'Mas immediate na throttle response; sporty na pakiramdam',
        'fuel_consumption_note': 'Bahagyang mas mataas sa city.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.1, afrWot: 12.9, stockRevLimitSoft: 10500),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': 'dohc', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'cbr150r_endurance',
        'motorcycle_model_id': id,
        'type': 'endurance',
        'name_taglish': 'Endurance — Para sa Mahabang Ride',
        'description_taglish':
            'Conservative timing, stable mid-range fueling, at walang speed limiter. '
            'Para sa mga nagma-motorista ng 100+ km sa isang araw.',
        'afr_target_mid': 13.3, 'afr_target_wot': 13.0,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 1,
        'safety_score': 94,
        'expected_benefits': 'Mas malamig na engine temp; stable na power delivery sa buong biyahe',
        'fuel_consumption_note': 'Halos katulad ng stock — sustainable para sa long rides.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.3, afrWot: 13.0, stockRevLimitSoft: 10500),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': 'dohc', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'cbr150r_exhaust',
        'motorcycle_model_id': id,
        'type': 'exhaustTune',
        'name_taglish': 'Exhaust Tune — Para sa Binagong Exhaust',
        'description_taglish':
            'Para sa mga CBR150R na may free-flow exhaust o tinanggal ang catalyst. '
            'Inaayos ang lean surge na dulot ng mas mabilis na exhaust flow.',
        'afr_target_mid': 13.0, 'afr_target_wot': 12.8,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 88,
        'expected_benefits': 'Inaalis ang lean surge; mas maayos ang power delivery sa aftermarket exhaust',
        'fuel_consumption_note': 'Mas mataas ng 8–10% dahil sa richer map.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.0, afrWot: 12.8, stockRevLimitSoft: 10500),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': 'dohc', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'cbr150r_track',
        'motorcycle_model_id': id,
        'type': 'track',
        'name_taglish': 'Track Mode — Para sa Circuit Lamang',
        'description_taglish':
            'Maximum performance. Lahat ng limiters inaalis. Aggressive timing (+4°) '
            'at WOT AFR para sa peak power. PARA SA TRACK LAMANG — hindi para sa daan.',
        'afr_target_mid': 12.9, 'afr_target_wot': 12.7,
        'timing_advance_deg': 4, 'rev_limit_raise': 1000, 'remove_speed_limiter': 1,
        'safety_score': 75,
        'expected_benefits': 'Maximum peak power; lahat ng safety limiters ay tinanggal',
        'fuel_consumption_note': 'RON97 na required. Hindi para sa kalsada.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 12.9, afrWot: 12.7, stockRevLimitSoft: 11500),
        'ignition_map_json': _buildIgnitionMapJson(34),
        'required_features': 'dohc,liquidCooled', 'incompatible_with': '', 'min_displacement': 145, 'max_displacement': 9999, 'fuel_requirement': 'RON97',
      },
    ]);
  }

  // ===========================================================================
  // 5. HONDA CB150R — 5 profiles (DOHC naked, casual commuter)
  // compressionRatio 10.7 → maxTimingAdvance +5°
  // ===========================================================================
  static Future<void> _seedCb150rProfiles(Database db) async {
    const id = 'honda_cb150r_std_2019';
    await _insert(db, [
      {
        'id': 'cb150r_eco',
        'motorcycle_model_id': id,
        'type': 'eco',
        'name_taglish': 'Eco — Tipid sa Gasolina',
        'description_taglish':
            'Lean at stable na AFR para sa pinaka-tipid na fuel consumption. '
            'Perpekto para sa everyday commuter ng CB150R.',
        'afr_target_mid': 14.0, 'afr_target_wot': 13.8,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 98,
        'expected_benefits': 'Est. 12–18% mas tipid; ideal para sa lungsod',
        'fuel_consumption_note': 'Pinaka-tipid na setup. Huwag gamitin sa WOT.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 14.0, afrWot: 13.8, stockRevLimitSoft: 10000),
        'ignition_map_json': _buildIgnitionMapJson(28),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'cb150r_balanced',
        'motorcycle_model_id': id,
        'type': 'balanced',
        'name_taglish': 'Balanced — Pinaka-Recommended',
        'description_taglish':
            'Best daily profile para sa CB150R. Mas mabilis na throttle, '
            'tinanggal ang speed limiter, at kaunting timing advance para sa mas maayos na pull.',
        'afr_target_mid': 13.3, 'afr_target_wot': 13.1,
        'timing_advance_deg': 3, 'rev_limit_raise': 300, 'remove_speed_limiter': 1,
        'safety_score': 92,
        'expected_benefits': 'Mas mabilis na throttle; tinanggal ang 125 km/h limiter; +3 km/h top',
        'fuel_consumption_note': 'Bahagyang mas mataas (~5%).',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.3, afrWot: 13.1, stockRevLimitSoft: 10300),
        'ignition_map_json': _buildIgnitionMapJson(33),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'cb150r_city',
        'motorcycle_model_id': id,
        'type': 'cityResponse',
        'name_taglish': 'City Response — Para sa EDSA Traffic',
        'description_taglish':
            'Mas aggressive na throttle map para sa mas mabilis na tugon sa traffic. '
            'Richer AFR sa mababang RPM para sa better pull mula sa stop.',
        'afr_target_mid': 13.5, 'afr_target_wot': 13.2,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 94,
        'expected_benefits': 'Mas mabilis na 0–50; sharper throttle response; stable sa traffic',
        'fuel_consumption_note': 'Bahagyang mas mataas sa city.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.5, afrWot: 13.2, stockRevLimitSoft: 10000),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'cb150r_endurance',
        'motorcycle_model_id': id,
        'type': 'endurance',
        'name_taglish': 'Endurance — Para sa Mahabang Biyahe',
        'description_taglish':
            'Dinisenyo para sa mga biyaheng higit sa 100 km. Stable na fueling, '
            'conservative timing, at walang speed limiter.',
        'afr_target_mid': 13.5, 'afr_target_wot': 13.2,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 1,
        'safety_score': 94,
        'expected_benefits': 'Mas malamig na engine; consistent na power delivery',
        'fuel_consumption_note': 'Katulad ng stock sa cruise speed.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.5, afrWot: 13.2, stockRevLimitSoft: 10000),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'cb150r_cold_start',
        'motorcycle_model_id': id,
        'type': 'coldStart',
        'name_taglish': 'Cold Start Fix — Ayusin ang Morning Start',
        'description_taglish':
            'Para sa mga CB150R na mahirap simulan sa umaga o nag-i-stall habang '
            'nagpapalasa pa. Nagdadagdag ng warmup enrichment sa mababang engine temp.',
        'afr_target_mid': 13.7, 'afr_target_wot': 13.2,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 99,
        'expected_benefits': 'Mas madaling simulan; hindi mag-i-stall sa unang 2–3 minuto',
        'fuel_consumption_note': 'Walang epekto sa pangkalahatang fuel economy.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.7, afrWot: 13.2, stockRevLimitSoft: 10000),
        'ignition_map_json': _buildIgnitionMapJson(30),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
    ]);
  }

  // ===========================================================================
  // 6. HONDA CLICK 125i — 5 profiles (air-cooled commuter scooter)
  // compressionRatio 11.0 → maxTimingAdvance +4°
  // ===========================================================================
  static Future<void> _seedClick125iProfiles(Database db) async {
    const id = 'honda_click125i_std_2021';
    await _insert(db, [
      {
        'id': 'click125i_eco',
        'motorcycle_model_id': id,
        'type': 'eco',
        'name_taglish': 'Eco — Makatipid Araw-Araw',
        'description_taglish':
            'Para sa Click 125i na ginagamit bilang everyday transport. '
            'Lean AFR para sa pinakamataas na fuel economy sa city.',
        'afr_target_mid': 14.0, 'afr_target_wot': 13.8,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 98,
        'expected_benefits': 'Est. 10–15% mas tipid; ideal para sa lungsod at under 70 km/h',
        'fuel_consumption_note': 'Pinaka-tipid. Huwag gamitin sa WOT.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 14.0, afrWot: 13.8, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(27),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'click125i_city',
        'motorcycle_model_id': id,
        'type': 'cityResponse',
        'name_taglish': 'City Response — Mas Bilis sa Traffic',
        'description_taglish':
            'Para sa Click na laging nasa trapik. Sharper throttle response, '
            'richer AFR sa mababang RPM para sa mas mabilis na pull.',
        'afr_target_mid': 13.6, 'afr_target_wot': 13.2,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 95,
        'expected_benefits': 'Mas mabilis na 0–40; mas madaling pumasok sa puwang sa traffic',
        'fuel_consumption_note': 'Bahagyang mas mataas sa city.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.6, afrWot: 13.2, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'click125i_balanced',
        'motorcycle_model_id': id,
        'type': 'balanced',
        'name_taglish': 'Balanced — Para sa City at Probinsya',
        'description_taglish':
            'Best all-around para sa Click. Mas mabilis na response sa lungsod, '
            'tinanggal ang speed limiter para sa probinsya.',
        'afr_target_mid': 13.5, 'afr_target_wot': 13.1,
        'timing_advance_deg': 3, 'rev_limit_raise': 500, 'remove_speed_limiter': 1,
        'safety_score': 91,
        'expected_benefits': 'Mas magandang all-around performance; tinanggal ang 110 km/h limiter',
        'fuel_consumption_note': 'Bahagyang mas mataas (~6%).',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.5, afrWot: 13.1, stockRevLimitSoft: 9000),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'click125i_idle',
        'motorcycle_model_id': id,
        'type': 'idleQuality',
        'name_taglish': 'Idle Fix — Ayusin ang Idle',
        'description_taglish':
            'Para sa mga Click na nag-i-stall sa traffic o hindi maayos ang idle. '
            'Itinatama ang idle mixture at target RPM.',
        'afr_target_mid': 13.9, 'afr_target_wot': 13.2,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 99,
        'expected_benefits': 'Stable idle; hindi mag-i-stall; mas maayos ang warm-up',
        'fuel_consumption_note': 'Walang epekto sa fuel economy.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.9, afrWot: 13.2, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(29),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
      {
        'id': 'click125i_altitude',
        'motorcycle_model_id': id,
        'type': 'altitudeCompensation',
        'name_taglish': 'Altitude — Para sa Baguio at Bundok',
        'description_taglish':
            'Mas lean na base map para sa 800–2000 MASL (elevation). '
            'Inaayos ang rich condition ng Click sa Baguio at iba pang matataas na lugar.',
        'afr_target_mid': 14.4, 'afr_target_wot': 14.1,
        'timing_advance_deg': 0, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 97,
        'expected_benefits': 'Tama ang fueling sa altitudo; hindi mag-i-stall sa bundok',
        'fuel_consumption_note': 'Katulad ng normal na fuel use. HUWAG gamitin sa sea level.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 14.4, afrWot: 14.1, stockRevLimitSoft: 8500),
        'ignition_map_json': _buildIgnitionMapJson(28),
        'required_features': '', 'incompatible_with': '', 'min_displacement': 0, 'max_displacement': 9999, 'fuel_requirement': 'RON91',
      },
    ]);
  }

  // ===========================================================================
  // 7. YAMAHA R3 — 6 profiles (DOHC 321cc, twin-cylinder sportbike)
  // compressionRatio 11.2 → maxTimingAdvance +4° | stock rev 12000
  // ===========================================================================
  static Future<void> _seedR3Profiles(Database db) async {
    const id = 'yamaha_r3_std_2019';
    await _insert(db, [
      {
        'id': 'r3_balanced',
        'motorcycle_model_id': id,
        'type': 'balanced',
        'name_taglish': 'Balanced — Best All-Around para sa R3',
        'description_taglish':
            'Pinaka-recommended para sa R3. Nagdadagdag ng timing advance (+3°), '
            'tinanggal ang speed limiter, at smoothed ang mid-range fueling.',
        'afr_target_mid': 13.1, 'afr_target_wot': 12.8,
        'timing_advance_deg': 3, 'rev_limit_raise': 500, 'remove_speed_limiter': 1,
        'safety_score': 90,
        'expected_benefits': '+6–8% mid-range; tinanggal ang 160 km/h limiter; improved pull',
        'fuel_consumption_note': 'Bahagyang mas mataas (~7%). Gamit RON95.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.1, afrWot: 12.8, stockRevLimitSoft: 12500),
        'ignition_map_json': _buildIgnitionMapJson(33),
        'required_features': 'dohc,displacement150Plus', 'incompatible_with': '', 'min_displacement': 300, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'r3_topspeed',
        'motorcycle_model_id': id,
        'type': 'topSpeed',
        'name_taglish': 'Top Speed — Max Performance',
        'description_taglish':
            'Maximum na performance ng R3. Max timing advance (+4°), '
            '+1000 RPM raise, enriched WOT AFR. Para sa track o highway.',
        'afr_target_mid': 12.9, 'afr_target_wot': 12.7,
        'timing_advance_deg': 4, 'rev_limit_raise': 1000, 'remove_speed_limiter': 1,
        'safety_score': 85,
        'expected_benefits': 'Pinaka-aggressive; +12–15 km/h top end; max na rev hang',
        'fuel_consumption_note': 'RON95 minimum, RON97 mas mainam. Mataas ang fuel use.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 12.9, afrWot: 12.7, stockRevLimitSoft: 13000),
        'ignition_map_json': _buildIgnitionMapJson(34),
        'required_features': 'dohc,displacement300Plus', 'incompatible_with': '', 'min_displacement': 300, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'r3_throttle_sharp',
        'motorcycle_model_id': id,
        'type': 'throttleSharpening',
        'name_taglish': 'Throttle Sharp — Mas Responsive na R3',
        'description_taglish':
            'Steeper TPS-fuel mapping para sa mas immediate na throttle response. '
            'Perpekto para sa sport riding at overtaking.',
        'afr_target_mid': 13.1, 'afr_target_wot': 12.8,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 92,
        'expected_benefits': 'Mas mabilis na throttle response; sporty na feel',
        'fuel_consumption_note': 'Bahagyang mas mataas sa city.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.1, afrWot: 12.8, stockRevLimitSoft: 12000),
        'ignition_map_json': _buildIgnitionMapJson(32),
        'required_features': 'dohc,displacement300Plus', 'incompatible_with': '', 'min_displacement': 300, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'r3_exhaust',
        'motorcycle_model_id': id,
        'type': 'exhaustTune',
        'name_taglish': 'Exhaust Tune — Para sa Aftermarket Exhaust',
        'description_taglish':
            'Para sa mga R3 na may aftermarket slip-on o full exhaust. '
            'Inaayos ang lean surge sa mid-range na sanhi ng mas mabilis na exhaust flow.',
        'afr_target_mid': 12.9, 'afr_target_wot': 12.7,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 0,
        'safety_score': 87,
        'expected_benefits': 'Inaalis ang lean surge; mas maayos na power kasama ang exhaust',
        'fuel_consumption_note': 'Mas mataas ng 8–10% dahil richer ang map.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 12.9, afrWot: 12.7, stockRevLimitSoft: 12000),
        'ignition_map_json': _buildIgnitionMapJson(33),
        'required_features': 'dohc,displacement300Plus', 'incompatible_with': '', 'min_displacement': 300, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'r3_endurance',
        'motorcycle_model_id': id,
        'type': 'endurance',
        'name_taglish': 'Endurance — Para sa Touring',
        'description_taglish':
            'Para sa mga R3 na ginagamit sa touring (Sagada, Bicol, Batanes). '
            'Stable fueling, conservative timing, at walang speed limiter.',
        'afr_target_mid': 13.2, 'afr_target_wot': 12.9,
        'timing_advance_deg': 2, 'rev_limit_raise': 0, 'remove_speed_limiter': 1,
        'safety_score': 93,
        'expected_benefits': 'Mas malamig na engine; stable sa 120–140 km/h cruise; angkop sa touring',
        'fuel_consumption_note': 'Katulad ng stock sa cruise — sustainable para sa mahabang biyahe.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 13.2, afrWot: 12.9, stockRevLimitSoft: 12000),
        'ignition_map_json': _buildIgnitionMapJson(31),
        'required_features': 'dohc,displacement300Plus', 'incompatible_with': '', 'min_displacement': 300, 'max_displacement': 9999, 'fuel_requirement': 'RON95',
      },
      {
        'id': 'r3_track',
        'motorcycle_model_id': id,
        'type': 'track',
        'name_taglish': 'Track Mode — Para sa Circuit',
        'description_taglish':
            'Full race tune. Lahat ng limiters ay tinanggal. Aggressive WOT AFR '
            'at timing para sa maximum na power. PARA SA TRACK LAMANG.',
        'afr_target_mid': 12.8, 'afr_target_wot': 12.5,
        'timing_advance_deg': 4, 'rev_limit_raise': 1000, 'remove_speed_limiter': 1,
        'safety_score': 72,
        'expected_benefits': 'Maximum peak power; lahat ng limiters tinanggal para sa circuit',
        'fuel_consumption_note': 'RON97 required. Hindi para sa kalsada.',
        'fuel_map_json': _buildFuelMapJson(afrMid: 12.8, afrWot: 12.5, stockRevLimitSoft: 13000),
        'ignition_map_json': _buildIgnitionMapJson(34),
        'required_features': 'dohc,displacement300Plus,liquidCooled', 'incompatible_with': '', 'min_displacement': 300, 'max_displacement': 9999, 'fuel_requirement': 'RON97',
      },
    ]);
  }
}
