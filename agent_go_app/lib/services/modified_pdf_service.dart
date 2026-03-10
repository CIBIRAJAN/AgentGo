import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import '../config/supabase_config.dart';

/// Generates a modified LIC due list PDF with phone numbers added.
class ModifiedPdfService {
  final SupabaseClient _client;

  ModifiedPdfService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch dues with all extracted columns and phone numbers.
  Future<List<Map<String, dynamic>>> getDuesWithPhones(String dueMonth) async {
    // 1. Fetch all dues for this month
    final response = await _client.from('monthly_dues').select('''
      policy_number,
      customer_name,
      premium_amount,
      gst_amount,
      total_premium,
      commission_amount,
      est_commission,
      due_month,
      due_date,
      doc,
      plan_term,
      mode,
      fup,
      fig,
      status
    ''').eq('user_id', _userId).eq('due_month', dueMonth).order('customer_name');

    final dues = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();

    // 2. Get all policy numbers
    final policyNumbers = dues.map((d) => d['policy_number']?.toString() ?? '').where((p) => p.isNotEmpty).toList();

    // 3. Fetch ALL clients for this user with their policy numbers and phone numbers
    final clientsResponse = await _client
        .from('client')
        .select('"Policy_Number", mobile_number, mobile_number_cc')
        .eq('user_id', _userId);

    // 4. Build a map of policy_number -> phone_number
    final phoneMap = <String, String>{};
    for (final c in (clientsResponse as List)) {
      final policy = c['Policy_Number']?.toString() ?? '';
      final cc = c['mobile_number_cc']?.toString() ?? '';
      final phone = c['mobile_number']?.toString() ?? '';
      if (policy.isNotEmpty && phone.isNotEmpty) {
        phoneMap[policy] = '$cc$phone';
      }
    }

    // 5. Merge phone numbers into dues by matching policy_number
    for (final due in dues) {
      final policy = due['policy_number']?.toString() ?? '';
      due['phone_number'] = phoneMap[policy] ?? '';
    }

    return dues;
  }

  /// Generate a PDF with the LIC due list + phone number column.
  /// Returns the PDF bytes.
  Future<Uint8List> generateModifiedPdf({
    required String dueMonth,
    String agentName = '',
    String agentCode = '',
    String branchCode = '',
  }) async {
    final dues = await getDuesWithPhones(dueMonth);

    final pdf = pw.Document();

    // Parse month for display
    String displayMonth = dueMonth;
    try {
      final parts = dueMonth.split('-');
      final months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      displayMonth = '${months[int.parse(parts[1])]} ${parts[0]}';
    } catch (_) {}

    // Calculate totals
    double totalPremium = 0;
    double totalGst = 0;
    double totalCommission = 0;
    for (final due in dues) {
      totalPremium += _toDouble(due['premium_amount']);
      totalGst += _toDouble(due['gst_amount']);
      totalCommission += _toDouble(due['commission_amount']);
    }

    // Build PDF pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        header: (context) => _buildHeader(
          context,
          agentName: agentName,
          agentCode: agentCode,
          branchCode: branchCode,
          dueMonth: displayMonth,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildTable(dues),
          pw.SizedBox(height: 8),
          _buildTotals(totalPremium, totalGst, totalCommission, dues.length),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
    pw.Context context, {
    required String agentName,
    required String agentCode,
    required String branchCode,
    required String dueMonth,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Branch Code: $branchCode',
                    style: pw.TextStyle(fontSize: 8)),
                pw.Text('Agent Name: $agentName',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Agent Code: $agentCode',
                    style: pw.TextStyle(fontSize: 8)),
              ],
            ),
            pw.Text('AgentGo - Modified Due List',
                style: pw.TextStyle(
                    fontSize: 7, color: PdfColor.fromHex('#6366F1'))),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#E8E0FF'),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Center(
            child: pw.Text(
              'Premium Due List For $dueMonth (with Phone Numbers)',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#4338CA'),
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _buildTable(List<Map<String, dynamic>> dues) {
    return pw.TableHelper.fromTextArray(
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.centerLeft,
      headerHeight: 22,
      cellHeight: 14,
      headerStyle: pw.TextStyle(
        fontSize: 6,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 5.5),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#7C3AED'),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      oddRowDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8F7FF'),
      ),
      headers: [
        'S.No',
        'PolicyNo',
        'Name of Assured',
        'D.o.C',
        'Pln/Tm',
        'Mod',
        'FUP',
        'Fig',
        'InstPrem',
        'Due',
        'GST',
        'TotPrem',
        'Phone Number',
      ],
      data: List.generate(dues.length, (i) {
        final d = dues[i];
        // FUP from extracted or due_month fallback
        String fup = d['fup']?.toString() ?? '';
        if (fup.isEmpty) {
          if (d['due_date'] != null && d['due_date'].toString().isNotEmpty) {
            fup = d['due_date'].toString();
          } else if (d['due_month'] != null) {
            fup = d['due_month'].toString();
          }
        }
        // Mode short form
        String mode = d['mode']?.toString() ?? '';
        if (mode.toLowerCase().contains('half')) mode = 'Hly';
        else if (mode.toLowerCase().contains('quar')) mode = 'Qly';
        else if (mode.toLowerCase().contains('month')) mode = 'Mly';
        else if (mode.toLowerCase().contains('year')) mode = 'Yly';

        return [
          '${i + 1}',
          d['policy_number']?.toString() ?? '',
          d['customer_name']?.toString() ?? '',
          d['doc']?.toString() ?? '',
          d['plan_term']?.toString() ?? '',
          mode,
          fup,
          d['fig']?.toString() ?? '',
          _formatNum(d['premium_amount']),
          _formatNum(d['commission_amount']),
          _formatNum(d['gst_amount']),
          _formatNum(d['total_premium']),
          d['phone_number']?.toString() ?? '',
        ];
      }),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),   // S.No
        1: const pw.FixedColumnWidth(55),   // PolicyNo
        2: const pw.FlexColumnWidth(2),     // Name
        3: const pw.FixedColumnWidth(55),   // D.o.C
        4: const pw.FixedColumnWidth(35),   // Pln/Tm
        5: const pw.FixedColumnWidth(22),   // Mod
        6: const pw.FixedColumnWidth(45),   // FUP
        7: const pw.FixedColumnWidth(22),   // Fig
        8: const pw.FixedColumnWidth(48),   // InstPrem
        9: const pw.FixedColumnWidth(28),   // Due
        10: const pw.FixedColumnWidth(38),  // GST
        11: const pw.FixedColumnWidth(48),  // TotPrem
        12: const pw.FixedColumnWidth(68),  // Phone
      },
    );
  }

  pw.Widget _buildTotals(
      double premium, double gst, double commission, int count) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FEF3C7'),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColor.fromHex('#F59E0B'), width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total ($count policies)',
              style:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text('Premium: ${_formatNum(premium)}',
              style: pw.TextStyle(fontSize: 9)),
          pw.Text('GST: ${_formatNum(gst)}',
              style: pw.TextStyle(fontSize: 9)),
          pw.Text('Est. Commission: ${_formatNum(commission)}',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#059669'))),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount} | Generated by AgentGo',
        style: pw.TextStyle(fontSize: 7, color: PdfColors.grey),
      ),
    );
  }

  /// Share/Print the generated PDF.
  Future<void> shareModifiedPdf({
    required String dueMonth,
    String agentName = '',
    String agentCode = '',
    String branchCode = '',
  }) async {
    final bytes = await generateModifiedPdf(
      dueMonth: dueMonth,
      agentName: agentName,
      agentCode: agentCode,
      branchCode: branchCode,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'AgentGo_DueList_$dueMonth.pdf',
    );
  }



  /// Upload modified PDF to Supabase storage.
  Future<String> uploadModifiedPdf({
    required Uint8List bytes,
    required String dueMonth,
  }) async {
    final fileName = 'modified_due_list_$dueMonth.pdf';
    final storagePath = '$_userId/modified/$fileName';

    await _client.storage.from(SupabaseConfig.pdfBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/pdf',
          ),
        );

    return _client.storage
        .from(SupabaseConfig.pdfBucket)
        .getPublicUrl(storagePath);
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _formatNum(dynamic value) {
    final v = _toDouble(value);
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(value.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}';
    } catch (_) {
      return value.toString();
    }
  }
}
