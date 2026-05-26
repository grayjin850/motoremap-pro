import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/binary/rom_parser.dart';
import '../core/ecu/ecu_definition.dart';
import 'model_packs/click125i_pack.dart';
import 'model_packs/aerox155_pack.dart';

// ── Safety hard limits (NEVER overridable) ────────────────────────────────────

class SafetyValidator {
  SafetyValidator._();

  /// Returns null if [suggestion] passes all safety checks, or an error string.
  static String? validate(TuningSuggestion suggestion, EcuDefinition ecu) {
    for (final change in suggestion.cellChanges) {
      final map = ecu.mapByName(change.mapName);
      if (map == null) return 'Unknown map: ${change.mapName}';

      final physical = change.newPhysicalValue;

      if (map.name.contains('fuel') || map.name.contains('injection')) {
        final limits = _afrLimitsFor(ecu);
        // Fuel values are pulse-width / enrichment — validate via map safe limits
        if (physical < map.safeMin) {
          return 'BLOCKED: ${map.name} value $physical below safe floor ${map.safeMin}';
        }
        if (physical > map.safeMax) {
          return 'BLOCKED: ${map.name} value $physical above safe ceiling ${map.safeMax}';
        }
        // AFR conceptual guard: extremely small fuel values indicate dangerous lean
        if (map.safeMin > 0 && physical < map.safeMin) {
          return 'BLOCKED: Fuel value would cause lean beyond ${limits.$1} AFR';
        }
      }

      if (map.name.contains('ignition') || map.name.contains('timing')) {
        final maxTiming = _maxTimingFor(ecu);
        if (physical > maxTiming) {
          return 'BLOCKED: Timing $physical° BTDC exceeds hard limit $maxTiming° BTDC';
        }
        if (physical < 0) {
          return 'BLOCKED: Negative timing value $physical° not allowed';
        }
      }

      // Generic map bounds
      if (physical < map.safeMin || physical > map.safeMax) {
        return 'BLOCKED: ${map.name} value $physical outside safe range '
            '[${map.safeMin}, ${map.safeMax}]';
      }
    }

    if (suggestion.revLimitRpm != null) {
      final maxRev = _maxRevLimitFor(ecu);
      if (suggestion.revLimitRpm! > maxRev) {
        return 'BLOCKED: Rev limit ${suggestion.revLimitRpm} RPM exceeds safe max $maxRev RPM';
      }
    }

    return null; // passed
  }

  static (double, double) _afrLimitsFor(EcuDefinition ecu) {
    if (ecu.id.contains('click')) {
      return (Click125iPack.absoluteAfrMin, Click125iPack.absoluteAfrMax);
    }
    return (Aerox155Pack.absoluteAfrMin, Aerox155Pack.absoluteAfrMax);
  }

  static double _maxTimingFor(EcuDefinition ecu) {
    if (ecu.id.contains('click')) return Click125iPack.maxTimingBtdc;
    return Aerox155Pack.maxTimingBtdc;
  }

  static int _maxRevLimitFor(EcuDefinition ecu) {
    if (ecu.id.contains('click')) return Click125iPack.maxSafeRevLimit;
    return Aerox155Pack.maxSafeRevLimit;
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class CellChange {
  final String mapName;
  final int row;
  final int col;
  final double originalPhysicalValue;
  final double newPhysicalValue;
  final String reasoning;

  const CellChange({
    required this.mapName,
    required this.row,
    required this.col,
    required this.originalPhysicalValue,
    required this.newPhysicalValue,
    required this.reasoning,
  });

  double get delta => newPhysicalValue - originalPhysicalValue;
}

enum RiskLevel { low, medium, high }

class TuningSuggestion {
  final String summary;
  final List<CellChange> cellChanges;
  final RiskLevel riskLevel;
  final String? revertInstructions;
  final int? revLimitRpm;
  final String rawAiResponse;
  // Non-null when SafetyValidator blocked part of the suggestion
  final String? safetyWarning;

  const TuningSuggestion({
    required this.summary,
    required this.cellChanges,
    required this.riskLevel,
    required this.rawAiResponse,
    this.revertInstructions,
    this.revLimitRpm,
    this.safetyWarning,
  });

  bool get isBlocked => safetyWarning != null && cellChanges.isEmpty;

  TuningSuggestion withWarning(String warning) => TuningSuggestion(
        summary: summary,
        cellChanges: cellChanges,
        riskLevel: riskLevel,
        rawAiResponse: rawAiResponse,
        revertInstructions: revertInstructions,
        revLimitRpm: revLimitRpm,
        safetyWarning: warning,
      );
}

// ── AI recommendation engine ──────────────────────────────────────────────────

class TuningAI {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';
  static const String _model = 'claude-opus-4-7';

  final String apiKey;

  const TuningAI({required this.apiKey});

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Ask the AI a free-form tuning question. Returns a [TuningSuggestion]
  /// where all cell changes have passed the [SafetyValidator].
  Future<TuningSuggestion> ask({
    required String userMessage,
    required EcuDefinition ecu,
    required ParsedRom rom,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    final systemPrompt = _buildSystemPrompt(ecu);
    final contextBlock = _buildRomContext(rom, ecu);
    final fullUserMessage = '$contextBlock\n\n$userMessage';

    final messages = [
      ...conversationHistory,
      {'role': 'user', 'content': fullUserMessage},
    ];

    final rawResponse = await _callClaudeApi(systemPrompt, messages);
    final suggestion = _parseSuggestion(rawResponse, rom, ecu);
    return _applySafetyFilter(suggestion, ecu);
  }

  // ── Claude API call ────────────────────────────────────────────────────────

  Future<String> _callClaudeApi(
    String systemPrompt,
    List<Map<String, String>> messages,
  ) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 2048,
        'system': systemPrompt,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw TuningAIException(
        'Claude API error ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>;
    if (content.isEmpty) throw const TuningAIException('Empty AI response');
    return (content.first as Map<String, dynamic>)['text'] as String;
  }

  // ── System prompt selection ────────────────────────────────────────────────

  static String _buildSystemPrompt(EcuDefinition ecu) {
    if (ecu.id.contains('click')) return Click125iPack.buildSystemPrompt();
    if (ecu.id.contains('aerox')) return Aerox155Pack.buildSystemPrompt();
    return _genericSystemPrompt(ecu);
  }

  static String _genericSystemPrompt(EcuDefinition ecu) {
    return '''
You are a professional motorcycle ECU tuning assistant.
ECU: ${ecu.displayName}, ${ecu.maps.length} maps loaded.

SAFETY RULES:
- Never suggest changes that risk engine damage.
- All fuel map values must stay within map safe limits.
- Timing values must never exceed the ECU maximum.
- Every suggestion must include revert instructions.

RESPONSE FORMAT:
- Specific map cells to change (row/col or RPM×TPS zone)
- Exact new value or percentage change
- Reasoning (what symptom this addresses)
- Risk level: LOW / MEDIUM / HIGH
- Revert: original values to restore if needed
''';
  }

  // ── ROM context builder ────────────────────────────────────────────────────

  static String _buildRomContext(ParsedRom rom, EcuDefinition ecu) {
    final buf = StringBuffer();
    buf.writeln('CURRENT ROM STATE:');
    for (final entry in rom.maps.entries) {
      final map = entry.value;
      buf.writeln('Map: ${entry.key} (${map.descriptor.rows}×${map.descriptor.cols})');
      // Show first 3×3 corner as a sample so AI has concrete values
      final rows = map.descriptor.rows < 3 ? map.descriptor.rows : 3;
      final cols = map.descriptor.cols < 3 ? map.descriptor.cols : 3;
      for (var r = 0; r < rows; r++) {
        final row = <String>[];
        for (var c = 0; c < cols; c++) {
          row.add(map.values[r][c].toStringAsFixed(1));
        }
        buf.writeln('  [${row.join(', ')} ...]');
      }
      buf.writeln('  (${map.descriptor.rows - rows} more rows...)');
    }
    return buf.toString();
  }

  // ── Response parser ────────────────────────────────────────────────────────

  /// Best-effort parse of the AI text response into structured [TuningSuggestion].
  /// The AI is prompted to use a known format; this extracts what it can.
  static TuningSuggestion _parseSuggestion(
    String raw,
    ParsedRom rom,
    EcuDefinition ecu,
  ) {
    final cellChanges = <CellChange>[];
    RiskLevel risk = RiskLevel.medium;
    String? revert;

    // Extract risk level
    if (raw.contains('Risk level: HIGH') || raw.contains('Risk Level: HIGH')) {
      risk = RiskLevel.high;
    } else if (raw.contains('Risk level: LOW') || raw.contains('Risk Level: LOW')) {
      risk = RiskLevel.low;
    }

    // Extract revert block
    final revertMatch = RegExp(
      r'Revert:(.*?)(?=\n[A-Z]|\Z)',
      dotAll: true,
    ).firstMatch(raw);
    if (revertMatch != null) {
      revert = revertMatch.group(1)?.trim();
    }

    // Extract cell changes — format expected:
    // Map: <mapName>, Row: <r>, Col: <c>, New value: <v>
    final cellPattern = RegExp(
      r'Map:\s*(\w+),\s*Row:\s*(\d+),\s*Col:\s*(\d+),\s*New value:\s*([\d.]+)',
      caseSensitive: false,
    );
    for (final match in cellPattern.allMatches(raw)) {
      final mapName = match.group(1)!;
      final row = int.tryParse(match.group(2)!) ?? -1;
      final col = int.tryParse(match.group(3)!) ?? -1;
      final newVal = double.tryParse(match.group(4)!) ?? 0;
      if (row < 0 || col < 0) continue;

      final extractedMap = rom.maps[mapName];
      if (extractedMap == null) continue;
      if (row >= extractedMap.descriptor.rows) continue;
      if (col >= extractedMap.descriptor.cols) continue;

      final originalVal = extractedMap.values[row][col];
      cellChanges.add(CellChange(
        mapName: mapName,
        row: row,
        col: col,
        originalPhysicalValue: originalVal,
        newPhysicalValue: newVal,
        reasoning: _extractReasoningFor(raw, mapName, row, col),
      ));
    }

    // Percentage-based format:
    // Map: <mapName>, RPM zone: <lo>–<hi>, TPS zone: <lo>–<hi>, Change: +<pct>%
    final zonePattern = RegExp(
      r'Map:\s*(\w+),\s*RPM zone:\s*(\d+)[–\-](\d+),\s*TPS zone:\s*(\d+)[–\-](\d+),\s*Change:\s*([+\-]?\d+\.?\d*)%',
      caseSensitive: false,
    );
    for (final match in zonePattern.allMatches(raw)) {
      final mapName = match.group(1)!;
      final rpmLo = int.tryParse(match.group(2)!) ?? 0;
      final rpmHi = int.tryParse(match.group(3)!) ?? 0;
      final tpsLo = int.tryParse(match.group(4)!) ?? 0;
      final tpsHi = int.tryParse(match.group(5)!) ?? 0;
      final pct = double.tryParse(match.group(6)!) ?? 0;

      final extractedMap = rom.maps[mapName];
      if (extractedMap == null) continue;
      if (ecu.mapByName(mapName) == null) continue;
      if (ecu.defaultAxes == null) continue;

      final rpmAxis = ecu.defaultAxes!.rpmPoints;
      final tpsAxis = ecu.defaultAxes!.loadPoints;

      for (var r = 0; r < rpmAxis.length; r++) {
        if (rpmAxis[r] < rpmLo || rpmAxis[r] > rpmHi) continue;
        for (var c = 0; c < tpsAxis.length; c++) {
          if (tpsAxis[c] < tpsLo || tpsAxis[c] > tpsHi) continue;
          final original = extractedMap.values[r][c];
          final newVal = original * (1 + pct / 100);
          cellChanges.add(CellChange(
            mapName: mapName,
            row: r,
            col: c,
            originalPhysicalValue: original,
            newPhysicalValue: newVal,
            reasoning: '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(1)}% zone adjustment',
          ));
        }
      }
    }

    return TuningSuggestion(
      summary: _extractSummary(raw),
      cellChanges: cellChanges,
      riskLevel: risk,
      rawAiResponse: raw,
      revertInstructions: revert,
    );
  }

  static String _extractSummary(String raw) {
    final lines = raw.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('Map:') &&
          !trimmed.startsWith('-') &&
          !trimmed.startsWith('#')) {
        return trimmed.length > 200 ? '${trimmed.substring(0, 200)}...' : trimmed;
      }
    }
    return raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;
  }

  static String _extractReasoningFor(String raw, String mapName, int row, int col) {
    // Look for a reasoning line after the Map/Row/Col line
    final pattern = RegExp(
      'Map:\\s*$mapName.*?Row:\\s*$row.*?Col:\\s*$col.*?\\n([^\\n]+)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(raw);
    return match?.group(1)?.trim() ?? 'See full AI response';
  }

  // ── Safety filter ─────────────────────────────────────────────────────────

  static TuningSuggestion _applySafetyFilter(
    TuningSuggestion suggestion,
    EcuDefinition ecu,
  ) {
    final safeChanges = <CellChange>[];
    final blocked = <String>[];

    for (final change in suggestion.cellChanges) {
      // Build a temporary single-change suggestion to validate
      final probe = TuningSuggestion(
        summary: '',
        cellChanges: [change],
        riskLevel: suggestion.riskLevel,
        rawAiResponse: '',
      );
      final error = SafetyValidator.validate(probe, ecu);
      if (error == null) {
        safeChanges.add(change);
      } else {
        blocked.add(error);
      }
    }

    // Also validate any rev limit change
    final revError = suggestion.revLimitRpm != null
        ? SafetyValidator.validate(suggestion, ecu)
        : null;
    if (revError != null) blocked.add(revError);

    final warning = blocked.isEmpty
        ? null
        : '${blocked.length} change(s) blocked by SafetyValidator:\n${blocked.join('\n')}';

    return TuningSuggestion(
      summary: suggestion.summary,
      cellChanges: safeChanges,
      riskLevel: suggestion.riskLevel,
      rawAiResponse: suggestion.rawAiResponse,
      revertInstructions: suggestion.revertInstructions,
      revLimitRpm: revError == null ? suggestion.revLimitRpm : null,
      safetyWarning: warning,
    );
  }
}

class TuningAIException implements Exception {
  final String message;
  const TuningAIException(this.message);
  @override
  String toString() => 'TuningAIException: $message';
}
