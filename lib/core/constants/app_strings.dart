class AppStrings {
  AppStrings._();

  // App identity
  static const String appName = 'MotoRemap Pro';
  static const String tagline = 'Professional ECU Remapping Assistant';
  static const String appVersion = 'v1.0.0';

  // Safety gate
  static const String safetyGateTitle = 'Babala — Safety Warning';
  static const String safetyGateBody =
      'Ang app na ito ay para lamang sa mga sinanay na motorcycle mechanic. '
      'Ang hindi tamang pag-tune ng ECU ay maaaring magdulot ng:\n\n'
      '• Engine damage (pisak na piston, sunog na valve)\n'
      '• Peligrosong kondisyon sa kalsada\n'
      '• Void ng warranty ng motorsiklo\n\n'
      'Siguraduhing naiintindihan mo ang lahat ng hakbang bago magpatuloy. '
      'Ang lahat ng pagbabago ay sa iyong sariling responsibilidad.\n\n'
      'I-type ang "SIGE NA" para kumpirmahin na ikaw ay isang sinanay na mechanic.';
  static const String safetyConfirmPhrase = 'SIGE NA';
  static const String safetyConfirmHint = 'I-type ang: SIGE NA';
  static const String safetyConfirmError =
      'Mali ang inilagay. Kailangang i-type ng eksakto: SIGE NA';
  static const String safetyProceedButton = 'Magpatuloy';
  static const String safetyCancelButton = 'Huwag na';

  // OBD / Bluetooth disclaimer
  static const String obdDisclaimer =
      'Paalala: Hindi lahat ng motorcycle ECU ay compatible sa OBD-II / ELM327. '
      'Ang mga lumang modelo (carbureted) ay walang OBD port. '
      'Para sa mga fuel-injected na motorsiklo, suriin muna ang manual ng sasakyan '
      'bago ikonekta ang OBD adapter. Ang maling koneksyon ay maaaring makasama '
      'sa ECU ng iyong motorsiklo.';

  static const String bluetoothNotAvailable =
      'Bluetooth is not available on this device. '
      'OBD live data features will be disabled.';

  static const String obdConnecting = 'Kinokonekta sa OBD adapter...';
  static const String obdConnected = 'Nakakonekta na!';
  static const String obdDisconnected = 'Nadiskonekta sa OBD adapter.';
  static const String obdNoData =
      'Walang datos na natanggap. Baka hindi compatible ang ECU ng iyong motorsiklo.';
  static const String obdSearching = 'Naghahanap ng Bluetooth devices...';
  static const String obdPairFirst =
      'I-pair muna ang iyong ELM327 adapter sa Bluetooth settings ng device.';

  // Warning messages (Taglish)
  static const String warningAFRLean =
      'BABALA: Masyadong payat ang halo ng gasolina at hangin (lean mixture)! '
      'Peligro ito sa engine — baka mawala ang lubrication.';
  static const String warningAFRRich =
      'PAALALA: Masyadong mataba ang halo (rich mixture). '
      'Mas mataas ang fuel consumption at maaaring ma-foul ang spark plug.';
  static const String warningHighTemp =
      'BABALA: Mainit na ang engine! Suriin ang coolant at radiator.';
  static const String warningBatteryLow =
      'Mababa na ang baterya ng motorsiklo. Suriin ang charging system.';
  static const String warningUnsavedChanges =
      'May mga pagbabago na hindi pa nase-save. Sigurado ka bang gusto mong lumabas?';
  static const String warningResetMap =
      'Ire-reset ang lahat ng halaga sa default. Sigurado ka ba?';
  static const String warningDeleteSession =
      'Tatanggalin ang session na ito. Hindi na ito maibabalik. Magpatuloy?';

  // Tune profile labels
  static const String profileStock = 'Stock / Default';
  static const String profileEco = 'Eco Mode (Matipid sa gasolina)';
  static const String profilePerformance = 'Performance (Para sa track)';
  static const String profileCustom = 'Custom';

  // Map viewer
  static const String fuelMapTitle = 'Fuel Map (AFR Table)';
  static const String ignitionMapTitle = 'Ignition Timing Map';
  static const String mapAxisRpm = 'RPM';
  static const String mapAxisTps = 'TPS (Throttle %)';
  static const String mapSaveChanges = 'I-save ang pagbabago';
  static const String mapUndoChanges = 'I-undo';
  static const String mapExportCsv = 'I-export bilang CSV';

  // Pre-remap screen
  static const String preRemapTitle = 'Pre-Remap Checklist';
  static const String preRemapSubtitle =
      'Suriin muna ang kondisyon ng motorsiklo bago mag-tune.';
  static const String faultCodeScanTitle = 'Fault Code Scanner';
  static const String faultCodeNone = 'Walang fault codes. Maayos ang ECU!';
  static const String faultCodeFound =
      'May nakitang fault codes. Ayusin muna bago mag-remap.';

  // Post-remap screen
  static const String postRemapTitle = 'Post-Remap Verification';
  static const String postRemapSubtitle =
      'I-verify ang resulta ng tune bago ibalik ang motorsiklo sa customer.';
  static const String postRemapExportPdf = 'I-export ang Report (PDF)';
  static const String postRemapSessionSaved = 'Na-save na ang session!';

  // Sessions screen
  static const String sessionsTitle = 'Mga Nakaraang Session';
  static const String sessionsEmpty = 'Wala pang nakaraang remap session.';
  static const String sessionsSearch = 'Maghanap ng session...';

  // Client screen
  static const String clientTitle = 'Client Information';
  static const String clientNameLabel = 'Pangalan ng Customer';
  static const String clientPhoneLabel = 'Telepono';
  static const String clientPlateLabel = 'Plate Number';
  static const String clientSave = 'I-save ang impormasyon';

  // Maintenance screen
  static const String maintenanceTitle = 'Maintenance Reminders';
  static const String maintenanceSubtitle =
      'Mga maintenance na kailangan pagkatapos ng remap.';
  static const String maintenanceOilChange =
      'Palitan ang motor oil pagkatapos ng 500km mula sa remap.';
  static const String maintenanceSparkPlug =
      'Suriin ang spark plug pagkatapos ng 1,000km.';
  static const String maintenanceAirFilter =
      'Linisin o palitan ang air filter.';
  static const String maintenanceFuelFilter =
      'Suriin ang fuel filter at fuel lines para sa leaks.';
  static const String maintenanceTireCheck =
      'Suriin ang kondisyon at presyon ng gulong bago sa track.';

  // Admin screen
  static const String adminTitle = 'Admin / Settings';
  static const String adminResetData = 'I-reset ang lahat ng data';
  static const String adminExportDb = 'I-export ang database';
  static const String adminAbout = 'Tungkol sa MotoRemap Pro';

  // General UI
  static const String buttonSave = 'I-save';
  static const String buttonCancel = 'Kanselahin';
  static const String buttonConfirm = 'Kumpirmahin';
  static const String buttonBack = 'Bumalik';
  static const String buttonNext = 'Susunod';
  static const String buttonStart = 'Simulan';
  static const String buttonStop = 'Itigil';
  static const String buttonConnect = 'Ikonekta';
  static const String buttonDisconnect = 'Idiskonekta';
  static const String loading = 'Naglo-load...';
  static const String error = 'Nagkaroon ng error. Subukan ulit.';
  static const String success = 'Matagumpay!';
  static const String noData = 'Walang datos';
  static const String comingSoon = 'Paparating pa...';
}
