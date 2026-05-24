class ObdCommands {
  ObdCommands._();

  // ELM327 initialization sequence
  static const String reset = 'ATZ';
  static const String echoOff = 'ATE0';
  static const String linefeeds = 'ATL0';
  static const String headersOff = 'ATH0';
  static const String autoProtocol = 'ATSP0';
  static const String supportedPids = '0100';

  // Standard OBD-II PIDs
  // Note: many of these return NODATA on motorcycle ECUs —
  // always check for NODATA before parsing the response.
  static const String rpm = '010C';
  static const String throttlePosition = '0111';
  static const String coolantTemp = '0105';
  static const String batteryVoltage = 'ATRV';
  static const String o2Sensor = '0114';
  static const String mapSensor = '010B';
  static const String injectorTiming = '0110'; // MAF sensor as proxy for injection

  // Response sentinel strings
  static const String noData = 'NODATA';
  static const String error = 'ERROR';
  static const String noResponse = 'NO RESPONSE';
  static const String searching = 'SEARCHING';
  static const String ok = 'OK';

  // ELM327 init sequence as ordered list (execute in order at connect)
  static const List<String> initSequence = [
    reset,
    echoOff,
    linefeeds,
    headersOff,
    autoProtocol,
  ];

  // Decode helpers — raw PID byte formulas
  // RPM: ((A * 256) + B) / 4  — result in RPM
  // Throttle: A * 100 / 255   — result in percent
  // Coolant temp: A - 40       — result in degrees Celsius
  // MAP sensor: A              — result in kPa
  // O2 sensor voltage: A * 0.005 — result in Volts (0.00–1.275V)
  static double decodeRpm(int a, int b) => ((a * 256) + b) / 4.0;
  static double decodeThrottle(int a) => (a * 100) / 255.0;
  static double decodeCoolantTemp(int a) => (a - 40).toDouble();
  static double decodeMap(int a) => a.toDouble();
  static double decodeO2Voltage(int a) => a * 0.005;
}
