import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../ecu/ecu_verification_manager.dart';

/// Generates a PDF validation report for a specific ECU's hardware verification chain.
///
/// The report documents every validation step — ROM dump, checksum, security access,
/// map offsets, and flash history — with timestamps and pass/fail status.
/// Intended for customer documentation and shop records.
class ValidationReport {
  ValidationReport._();

  /// Generate a PDF for [ecuId] and open the system share sheet.
  static Future<void> exportAndShare(String ecuId) async {
    final pdfBytes = await generate(ecuId);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'validation_${ecuId}_${_datestamp()}.pdf',
    );
  }

  /// Generate and return the raw PDF bytes for [ecuId].
  static Future<Uint8List> generate(String ecuId) async {
    final mgr = EcuVerificationManager.instance;
    await mgr.load();
    final record = mgr.recordFor(ecuId);
    final status = mgr.statusFor(ecuId);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          _header(ecuId, status),
          pw.SizedBox(height: 16),
          _statusSummary(status),
          pw.SizedBox(height: 16),
          if (record != null) ...[
            _checklist(record),
            pw.SizedBox(height: 16),
            if (record.validatedMapOffsets.isNotEmpty)
              _offsetTable(record.validatedMapOffsets),
            pw.SizedBox(height: 16),
            _flashHistory(record),
          ] else
            _noRecordNotice(),
          pw.SizedBox(height: 24),
          _footer(),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  static pw.Widget _header(String ecuId, VerificationStatus status) {
    final statusColor = switch (status) {
      VerificationStatus.verified => PdfColors.green800,
      VerificationStatus.partial => PdfColors.orange800,
      VerificationStatus.unverified => PdfColors.red800,
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MotoRemap Pro — ECU Validation Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('ECU ID: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(ecuId),
            pw.Spacer(),
            pw.Text('Date: ${DateTime.now().toLocal().toString().substring(0, 16)}'),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('Status: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(
              status.label,
              style: pw.TextStyle(
                color: statusColor,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _statusSummary(VerificationStatus status) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: status == VerificationStatus.verified
            ? PdfColors.green50
            : PdfColors.orange50,
        border: pw.Border.all(
          color: status == VerificationStatus.verified
              ? PdfColors.green200
              : PdfColors.orange200,
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(status.description, style: const pw.TextStyle(fontSize: 11)),
    );
  }

  static pw.Widget _checklist(VerificationRecord record) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Validation Checklist'),
        pw.SizedBox(height: 6),
        _checkRow(
          'ROM Dump',
          record.romDumpHash != null,
          record.romDumpHash != null
              ? 'Hash: ${record.romDumpHash}  •  '
                  'Size: ${record.romSizeBytes} bytes  •  '
                  '${_fmtDate(record.romDumpAt)}'
              : 'Not performed',
        ),
        _checkRow(
          'Checksum Algorithm',
          record.checksumValidated,
          record.checksumValidated
              ? 'Verified against real ROM dump'
              : 'Not validated — using community estimates',
        ),
        _checkRow(
          'Security Access (seed→key)',
          record.securityAccessConfirmed,
          record.securityAccessConfirmed
              ? 'Confirmed on real hardware'
              : 'Not confirmed — algorithm unverified',
        ),
        _checkRow(
          'Map Offsets',
          record.validatedMapOffsets.isNotEmpty,
          record.validatedMapOffsets.isNotEmpty
              ? '${record.validatedMapOffsets.length} map(s) validated'
              : 'Not validated — offsets are community estimates',
        ),
        _checkRow(
          'Successful Flash + Reboot',
          record.flashCount > 0,
          record.flashCount > 0
              ? '${record.flashCount} flash(es) completed  •  '
                  'Last: ${_fmtDate(record.lastSuccessfulFlashAt)}'
              : 'No successful flash recorded',
        ),
      ],
    );
  }

  static pw.Widget _checkRow(String label, bool passed, String detail) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            passed ? '✓' : '✗',
            style: pw.TextStyle(
              color: passed ? PdfColors.green700 : PdfColors.red700,
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text(detail,
                    style: const pw.TextStyle(fontSize: 10,
                        color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _offsetTable(Map<String, int> offsets) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Validated Map Offsets'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('Map Name', bold: true),
                _tableCell('ROM Offset', bold: true),
              ],
            ),
            ...offsets.entries.map((e) => pw.TableRow(
                  children: [
                    _tableCell(e.key),
                    _tableCell(
                        '0x${e.value.toRadixString(16).toUpperCase().padLeft(4, '0')}'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  static pw.Widget _flashHistory(VerificationRecord record) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Flash History'),
        pw.SizedBox(height: 6),
        pw.Text('Total successful flashes: ${record.flashCount}',
            style: const pw.TextStyle(fontSize: 11)),
        if (record.lastSuccessfulFlashAt != null) ...[
          pw.SizedBox(height: 2),
          pw.Text('Last successful flash: ${_fmtDate(record.lastSuccessfulFlashAt)}',
              style: const pw.TextStyle(fontSize: 11)),
        ],
      ],
    );
  }

  static pw.Widget _noRecordNotice() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border.all(color: PdfColors.orange400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'No validation record found for this ECU. '
        'Connect to real hardware and complete the 8-step validation chain '
        'before considering this ECU safe to flash.',
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }

  static pw.Widget _footer() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Text(
        'Generated by MotoRemap Pro. '
        'This report is for professional mechanic reference only. '
        'All flashing operations carry risk — keep backups.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) => pw.Text(
        title,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
      );

  static pw.Widget _tableCell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return dt.toLocal().toString().substring(0, 16);
  }

  static String _datestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
