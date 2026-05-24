import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/session_log.dart';
import '../../models/motorcycle_model.dart';
import '../../models/tune_profile.dart';
import '../../models/client_model.dart';

// ---------------------------------------------------------------------------
// PdfGenerator
// ---------------------------------------------------------------------------

/// Generates PDF reports for MotoRemap Pro sessions.
///
/// Both generation methods offload PDF construction to a background isolate
/// via [compute()] to prevent UI jank during large document builds.
class PdfGenerator {
  PdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generate a full technical report containing all session parameters,
  /// safety scores, tune profile details, and an OBD data summary.
  ///
  /// PDF construction runs in an isolate — safe to await on the UI thread.
  static Future<Uint8List> generateTechnicalReport({
    required SessionLog session,
    required MotorcycleModel model,
    TuneProfile? profile,
  }) {
    return compute(
      _buildTechnicalReport,
      {
        'session': session.toMap(),
        'model': model.toMap(),
        'profile': profile?.toMap(),
      },
    );
  }

  /// Generate a simplified client-facing report in Taglish.
  ///
  /// Includes: what was changed, expected benefits, maintenance reminders,
  /// and the warranty disclaimer. Runs in an isolate.
  static Future<Uint8List> generateClientReport({
    required SessionLog session,
    required MotorcycleModel model,
    TuneProfile? profile,
    ClientModel? client,
  }) {
    return compute(
      _buildClientReport,
      {
        'session': session.toMap(),
        'model': model.toMap(),
        'profile': profile?.toMap(),
        'client': client?.toMap(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Private isolate functions
  // Must be top-level or static for compute() — cannot close over instance state.
  // ---------------------------------------------------------------------------

  static Future<Uint8List> _buildTechnicalReport(
      Map<String, dynamic> data) async {
    final sessionMap = data['session'] as Map<String, dynamic>;
    final modelMap = data['model'] as Map<String, dynamic>;
    final profileMap = data['profile'] as Map<String, dynamic>?;

    final doc = pw.Document();

    final headerStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );
    final labelStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
    );
    final valueStyle = const pw.TextStyle(fontSize: 10);
    final sectionStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blueGrey800,
    );

    // -------------------------------------------------------------------------
    // Helper: build a two-column data row
    pw.Widget dataRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 160,
              child: pw.Text(label, style: labelStyle),
            ),
            pw.Expanded(child: pw.Text(value, style: valueStyle)),
          ],
        ),
      );
    }

    // -------------------------------------------------------------------------
    // Helper: section divider
    pw.Widget sectionHeader(String title) {
      return pw.Column(children: [
        pw.SizedBox(height: 12),
        pw.Text(title, style: sectionStyle),
        pw.Divider(thickness: 0.5, color: PdfColors.blueGrey300),
        pw.SizedBox(height: 4),
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MotoRemap Pro — Technical Report', style: headerStyle),
                pw.Text(
                  'Page ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blueGrey900),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'CONFIDENTIAL — For authorized technician use only',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          // ----------------------------------------------------------------
          // Session metadata
          sectionHeader('Session Information'),
          dataRow('Session ID', sessionMap['id']?.toString() ?? '-'),
          dataRow('Timestamp', sessionMap['timestamp']?.toString() ?? '-'),
          dataRow(
            'Result',
            (sessionMap['result']?.toString() ?? 'success').toUpperCase(),
          ),
          dataRow(
            'Requires Follow-Up',
            (sessionMap['requiresFollowUp'] as int? ?? 0) == 1 ? 'YES' : 'No',
          ),

          // ----------------------------------------------------------------
          // Motorcycle details
          sectionHeader('Motorcycle'),
          dataRow('Brand', modelMap['brand']?.toString() ?? '-'),
          dataRow('Model', modelMap['model']?.toString() ?? '-'),
          dataRow('Variant', modelMap['variant']?.toString() ?? '-'),
          dataRow(
            'Year Range',
            '${modelMap['yearFrom']} – '
                '${(modelMap['yearTo'] as int? ?? 0) == 0 ? 'Present' : modelMap['yearTo']}',
          ),
          dataRow('Engine', '${modelMap['displacement']} cc'),
          dataRow('Valve System', modelMap['valveSystem']?.toString() ?? '-'),
          dataRow('Cooling', modelMap['cooling']?.toString() ?? '-'),
          dataRow('ECU Type', modelMap['ecuType']?.toString() ?? '-'),
          dataRow('Flash Tool', modelMap['flashTool']?.toString() ?? '-'),
          dataRow(
            'Compression Ratio',
            '${modelMap['compressionRatio']}:1',
          ),
          dataRow(
            'Stock Rev Limit (soft/hard)',
            '${modelMap['stockRevLimitSoft']} / ${modelMap['stockRevLimitHard']} RPM',
          ),
          dataRow(
            'Stock Speed Limit',
            '${modelMap['stockSpeedLimit']} km/h',
          ),
          dataRow(
            'Safe AFR Range (mid/WOT)',
            '${modelMap['safeAfrMid']} / ${modelMap['safeAfrWot']}',
          ),

          // ----------------------------------------------------------------
          // Safety scores
          sectionHeader('Safety Scores'),
          dataRow(
            'Pre-Remap Score',
            '${sessionMap['preRemapSafetyScore']} / 100',
          ),
          dataRow(
            'Tune Safety Score',
            sessionMap['tuneSafetyScore'] != null
                ? '${sessionMap['tuneSafetyScore']} / 100'
                : 'N/A',
          ),
          if ((sessionMap['warningsTriggered']?.toString() ?? '').isNotEmpty)
            dataRow(
              'Warnings Triggered',
              sessionMap['warningsTriggered'].toString().replaceAll('|', '\n'),
            ),

          // ----------------------------------------------------------------
          // Client info (if provided)
          if (sessionMap['clientName'] != null) ...[
            sectionHeader('Client Information'),
            dataRow('Name', sessionMap['clientName']?.toString() ?? '-'),
            dataRow('Plate', sessionMap['clientPlate']?.toString() ?? '-'),
          ],

          // ----------------------------------------------------------------
          // Tune profile (if applied)
          if (profileMap != null) ...[
            sectionHeader('Tune Profile Applied'),
            dataRow('Profile Name', profileMap['nameTaglish']?.toString() ?? '-'),
            dataRow(
              'Type',
              profileMap['type']?.toString().toUpperCase() ?? '-',
            ),
            dataRow(
              'AFR Target (mid/WOT)',
              '${profileMap['afrTargetMid']} / ${profileMap['afrTargetWot']}',
            ),
            dataRow(
              'Timing Advance',
              '${profileMap['timingAdvanceDeg']}°',
            ),
            dataRow(
              'Rev Limit Raise',
              '${profileMap['revLimitRaise']} RPM',
            ),
            dataRow(
              'Speed Limiter Removed',
              (profileMap['removeSpeedLimiter'] as int? ?? 0) == 1 ? 'YES' : 'No',
            ),
            dataRow(
              'Computed Tune Safety Score',
              sessionMap['tuneSafetyScore'] != null
                  ? '${sessionMap['tuneSafetyScore']} / 100'
                  : '${profileMap['safetyScore']} / 100 (reference only)',
            ),
            dataRow(
              'Expected Benefits',
              profileMap['expectedBenefits']?.toString() ?? '-',
            ),
            dataRow(
              'Fuel Consumption Note',
              profileMap['fuelConsumptionNote']?.toString() ?? '-',
            ),
          ] else ...[
            sectionHeader('Tune Profile'),
            pw.Text(
              'No tune profile was applied in this session.',
              style: valueStyle,
            ),
          ],

          // ----------------------------------------------------------------
          // OBD data summary (if captured)
          sectionHeader('OBD Data Summary'),
          pw.Text(
            sessionMap['obdDataSummary']?.toString().isNotEmpty == true
                ? sessionMap['obdDataSummary'].toString()
                : 'No OBD data captured in this session.',
            style: valueStyle,
          ),

          // ----------------------------------------------------------------
          // Technician notes
          if ((sessionMap['technicianNotes']?.toString() ?? '').isNotEmpty) ...[
            sectionHeader('Technician Notes'),
            pw.Text(
              sessionMap['technicianNotes'].toString(),
              style: valueStyle,
            ),
          ],

          pw.SizedBox(height: 24),
          pw.Text(
            'Generated by MotoRemap Pro v1.0',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------

  static Future<Uint8List> _buildClientReport(
      Map<String, dynamic> data) async {
    final sessionMap = data['session'] as Map<String, dynamic>;
    final modelMap = data['model'] as Map<String, dynamic>;
    final profileMap = data['profile'] as Map<String, dynamic>?;
    final clientMap = data['client'] as Map<String, dynamic>?;

    final doc = pw.Document();

    final titleStyle = pw.TextStyle(
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blueGrey800,
    );
    final bodyStyle = const pw.TextStyle(fontSize: 10);
    final smallStyle = const pw.TextStyle(fontSize: 8, color: PdfColors.grey);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          // ----------------------------------------------------------------
          // Header / title
          pw.Center(
            child: pw.Text('MOTORCYCLE ECU REMAP REPORT', style: titleStyle),
          ),
          pw.Center(
            child: pw.Text('MotoRemap Pro', style: smallStyle),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 12),

          // ----------------------------------------------------------------
          // Client / unit info
          pw.Text('Impormasyon ng Sasakyan', style: sectionStyle),
          pw.SizedBox(height: 4),
          pw.Text(
            'Brand/Model: ${modelMap['brand']} ${modelMap['model']} ${modelMap['variant']}',
            style: bodyStyle,
          ),
          if (clientMap != null) ...[
            pw.Text('Pangalan: ${clientMap['name']}', style: bodyStyle),
            if (clientMap['plateNumber'] != null)
              pw.Text('Plate No: ${clientMap['plateNumber']}', style: bodyStyle),
            if (clientMap['phone'] != null)
              pw.Text('Telepono: ${clientMap['phone']}', style: bodyStyle),
          ] else if (sessionMap['clientName'] != null) ...[
            pw.Text('Pangalan: ${sessionMap['clientName']}', style: bodyStyle),
            if (sessionMap['clientPlate'] != null)
              pw.Text('Plate No: ${sessionMap['clientPlate']}', style: bodyStyle),
          ],
          pw.Text(
            'Petsa ng Serbisyo: ${_formatDate(sessionMap['timestamp']?.toString())}',
            style: bodyStyle,
          ),
          pw.SizedBox(height: 16),

          // ----------------------------------------------------------------
          // What was done (Taglish)
          pw.Text('Ano ang Ginawa sa Inyong Motorsiklo', style: sectionStyle),
          pw.SizedBox(height: 4),
          if (profileMap != null) ...[
            pw.Text(
              'Tune Profile: ${profileMap['nameTaglish']}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              profileMap['descriptionTaglish']?.toString() ??
                  'Binago ang fuel at ignition settings ng inyong motorsiklo '
                      'para ma-optimize ang performance at efficiency.',
              style: bodyStyle,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Mga Inaasahang Benepisyo:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              profileMap['expectedBenefits']?.toString() ?? '-',
              style: bodyStyle,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Tungkol sa Gasolina:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              profileMap['fuelConsumptionNote']?.toString() ?? '-',
              style: bodyStyle,
            ),
          ] else ...[
            pw.Text(
              'Nagsagawa ng diagnostics at pre-remap inspection. '
              'Walang tune profile ang na-apply sa session na ito.',
              style: bodyStyle,
            ),
          ],
          pw.SizedBox(height: 16),

          // ----------------------------------------------------------------
          // Safety score summary
          pw.Text('Safety Check', style: sectionStyle),
          pw.SizedBox(height: 4),
          pw.Text(
            'Pre-Remap Safety Score: ${sessionMap['preRemapSafetyScore']}/100',
            style: bodyStyle,
          ),
          if (sessionMap['tuneSafetyScore'] != null)
            pw.Text(
              'Tune Safety Score: ${sessionMap['tuneSafetyScore']}/100',
              style: bodyStyle,
            ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Ang lahat ng settings ay nasubok at napatunayan na ligtas '
            'para sa inyong sasakyan bago i-apply.',
            style: bodyStyle,
          ),
          pw.SizedBox(height: 16),

          // ----------------------------------------------------------------
          // Maintenance reminders (Taglish)
          pw.Text('Mga Paalala sa Maintenance', style: sectionStyle),
          pw.SizedBox(height: 4),
          _bulletPoint(
            'Palitan ang engine oil bawat 1,000–1,500 km '
            'para mapanatili ang buhay ng makina.',
            bodyStyle,
          ),
          _bulletPoint(
            'Gamitin ang tamang grade ng gasolina na '
            'inirerekomenda para sa inyong motorsiklo.',
            bodyStyle,
          ),
          _bulletPoint(
            'I-check ang spark plug tuwing 3,000 km at palitan '
            'kung kinakailangan.',
            bodyStyle,
          ),
          _bulletPoint(
            'Siguraduhing maayos ang air filter para mapanatili '
            'ang maayos na combustion.',
            bodyStyle,
          ),
          _bulletPoint(
            'Bumalik para sa post-remap check-up pagkatapos ng '
            '500 km o isang buwan.',
            bodyStyle,
          ),
          if ((sessionMap['requiresFollowUp'] as int? ?? 0) == 1) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.orange),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'PAALALA: Kailangang mag-follow-up para sa kumpletong '
                'serbisyo ng inyong motorsiklo.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.orange900,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 16),

          // ----------------------------------------------------------------
          // Warranty disclaimer
          pw.Text('Disclaimer / Pagtatanggi', style: sectionStyle),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Ang ECU remapping ay isang advanced na modipikasyon. '
                  'Ang MotoRemap Pro at ang nagbigay ng serbisyo ay hindi '
                  'mananagot sa anumang pinsala na maaaring mangyari kung '
                  'hindi susundin ang mga rekomendasyon sa maintenance.',
                  style: bodyStyle,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'BABALA: Ang paggamit ng mababang kalidad na gasolina, '
                  'pag-skip ng oil changes, o pagbabago ng ibang bahagi nang '
                  'walang konsultasyon ay maaaring magdulot ng pinsala sa makina '
                  'at maaaring mapawalang-bisa ang garantiya ng serbisyong ito.',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.red900,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // ----------------------------------------------------------------
          // Signature line
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.SizedBox(height: 30),
                pw.Container(width: 150, height: 0.5, color: PdfColors.black),
                pw.Text('Pirma ng Kliyente', style: smallStyle),
              ]),
              pw.Column(children: [
                pw.SizedBox(height: 30),
                pw.Container(width: 150, height: 0.5, color: PdfColors.black),
                pw.Text('Pirma ng Technician', style: smallStyle),
              ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              'Salamat sa inyong tiwala sa MotoRemap Pro.',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.blueGrey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Generated by MotoRemap Pro v1.0  |  '
              '${_formatDate(DateTime.now().toIso8601String())}',
              style: smallStyle,
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Private formatting helpers (static — usable inside isolate functions)
  // ---------------------------------------------------------------------------

  static pw.Widget _bulletPoint(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: style),
          pw.Expanded(child: pw.Text(text, style: style)),
        ],
      ),
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
