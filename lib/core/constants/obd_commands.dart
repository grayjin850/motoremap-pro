/// OBD-II PID constants and ELM327 AT-command constants.
///
/// All standard PIDs follow SAE J1979 Mode 01 (current data) format.
/// Formula comments show how to convert raw bytes to physical values.
/// Non-standard PIDs (e.g., 01A6 knock retard) are noted explicitly.
class ObdCommands {
  ObdCommands._();

  // ---------------------------------------------------------------------------
  // ELM327 initialization sequence — send in order at connect
  // ---------------------------------------------------------------------------
  static const String reset          = 'ATZ';
  static const String echoOff        = 'ATE0';
  static const String linefeeds      = 'ATL0';
  static const String headersOff     = 'ATH0';
  static const String autoProtocol   = 'ATSP0';
  static const String supportedPids  = '0100';

  // ---------------------------------------------------------------------------
  // Mode 01 — Standard OBD-II live data PIDs
  // ---------------------------------------------------------------------------

  /// Engine RPM.
  /// Formula: ((A * 256) + B) / 4  → RPM (0–16383)
  static const String rpm = '010C';

  /// Throttle position sensor (TPS).
  /// Formula: A * 100 / 255  → percent (0–100%)
  static const String throttlePosition = '0111';

  /// Engine coolant temperature.
  /// Formula: A - 40  → °C (-40 to 215°C)
  static const String coolantTemp = '0105';

  /// Battery/alternator voltage (ELM327 AT command, not a standard OBD PID).
  /// Returns string like "12.6V".
  static const String batteryVoltage = 'ATRV';

  /// Narrowband O2 sensor voltage, bank 1 sensor 1.
  /// Formula: A * 0.005  → Volts (0.00–1.275V)
  /// NOTE: This is NOT AFR — use AfrCalculator to estimate AFR from this value.
  static const String o2Sensor = '0114';

  /// Manifold absolute pressure (MAP) sensor.
  /// Formula: A  → kPa (0–255)
  static const String mapSensor = '010B';

  /// Intake air temperature (IAT).
  /// Formula: A - 40  → °C (-40 to 215°C)
  static const String intakeAirTemp = '010F';

  /// Calculated engine load.
  /// Formula: A * 100 / 255  → percent (0–100%)
  static const String engineLoad = '0104';

  /// Short-term fuel trim, bank 1.
  /// Formula: (A - 128) * 100 / 128  → percent (-100% to +99.2%)
  /// Positive = adding fuel (lean condition), negative = removing fuel (rich)
  static const String fuelTrimShortTerm = '0106';

  /// Long-term fuel trim, bank 1.
  /// Formula: (A - 128) * 100 / 128  → percent (-100% to +99.2%)
  static const String fuelTrimLongTerm = '0107';

  /// Fuel pressure (gauge pressure).
  /// Formula: A * 3  → kPa (0–765 kPa)
  static const String fuelPressure = '010A';

  /// Knock retard / spark advance (non-standard PID 01A6).
  /// Formula: (A - 128) / 2  → degrees advance (negative = retard)
  /// NOTE: Most motorcycle ECUs return NODATA for this PID.
  /// Only supported on select Yamaha Shindengen ECUs with firmware extension.
  static const String knockRetard = '01A6';

  // ---------------------------------------------------------------------------
  // Mode 09 — Vehicle/ECU identification
  // ---------------------------------------------------------------------------

  /// Vehicle Identification Number (VIN). Returns up to 17 ASCII characters.
  /// Many motorcycle ECUs return NODATA — not all support Mode 09.
  static const String vin = '0902';

  /// ECU calibration ID. Identifies the firmware version flashed on the ECU.
  static const String calibrationId = '0904';

  /// ECU part number.
  static const String ecuPartNumber = '0906';

  // ---------------------------------------------------------------------------
  // ELM327 response sentinels
  // ---------------------------------------------------------------------------
  static const String noData     = 'NODATA';
  static const String error      = 'ERROR';
  static const String noResponse = 'NO RESPONSE';
  static const String searching  = 'SEARCHING';
  static const String ok         = 'OK';

  // ---------------------------------------------------------------------------
  // Ordered init sequence
  // ---------------------------------------------------------------------------
  static const List<String> initSequence = [
    reset,
    echoOff,
    linefeeds,
    headersOff,
    autoProtocol,
  ];

  // ---------------------------------------------------------------------------
  // Standard PID decode helpers (static pure functions)
  // ---------------------------------------------------------------------------

  /// RPM: ((A * 256) + B) / 4
  static double decodeRpm(int a, int b) => ((a * 256) + b) / 4.0;

  /// Throttle / engine load: A * 100 / 255
  static double decodePercentA(int a) => (a * 100) / 255.0;

  /// Temperature (coolant, IAT): A - 40
  static double decodeTemp(int a) => (a - 40).toDouble();

  /// MAP sensor: A (kPa directly)
  static double decodeMap(int a) => a.toDouble();

  /// Narrowband O2 voltage: A * 0.005
  static double decodeO2Voltage(int a) => a * 0.005;

  /// Fuel trim: (A - 128) * 100 / 128
  static double decodeFuelTrim(int a) => (a - 128) * 100.0 / 128.0;

  /// Fuel pressure: A * 3 (kPa)
  static double decodeFuelPressure(int a) => a * 3.0;

  /// Knock retard / spark advance: (A - 128) / 2
  /// Returns negative degrees for retard, positive for advance
  static double decodeSparkAdvance(int a) => (a - 128) / 2.0;
}
