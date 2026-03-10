import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Extracts due data from an LIC PDF and sends it to the Edge Function.
class PdfProcessingService {
  final SupabaseClient _client;

  PdfProcessingService(this._client);

  /// Extract text from PDF bytes, parse dues, and save to database.
  Future<Map<String, dynamic>> processPdf({
    required Uint8List pdfBytes,
    required String pdfUploadId,
    required String dueMonth,
    String? targetUserId, // Added: Which agent is this for?
  }) async {
    // 1. Extract text lines from all pages
    final allLines = _extractTextLines(pdfBytes);

    debugPrint('=== Extracted ${allLines.length} lines ===');
    for (int i = 0; i < allLines.length && i < 20; i++) {
      debugPrint('LINE $i: ${allLines[i]}');
    }

    // 2. Parse the extracted text into dues records
    final dues = _parseLicDueList(allLines, dueMonth);

    debugPrint('=== PARSED ${dues.length} DUES ===');
    if (dues.isNotEmpty) {
      debugPrint('First: ${dues.first}');
      debugPrint('Last: ${dues.last}');
    }

    if (dues.isEmpty) {
      await _client.from('pdf_uploads').update({
        'status': 'failed',
        'error_message': 'No dues could be extracted from this PDF',
      }).eq('id', pdfUploadId);

      throw Exception(
          'Could not extract dues from this PDF. Make sure it is an LIC due-list format.');
    }

    // 3. Update status to processing
    await _client.from('pdf_uploads').update({
      'status': 'processing',
    }).eq('id', pdfUploadId);

    // 4. Direct insert with all columns
    return await _directInsert(dues, pdfUploadId, dueMonth, targetUserId: targetUserId);
  }

  /// Process a commission/salary PDF to mark dues as paid.
  Future<Map<String, dynamic>> processCommissionPdf({
    required Uint8List pdfBytes,
    required String commissionUploadId,
    String? targetUserId,
  }) async {
    final ownerId = targetUserId ?? _client.auth.currentUser!.id;
    
    // 1. Extract text lines
    final allLines = _extractTextLines(pdfBytes);
    
    // 2. Extract unique 9-digit policy numbers
    final policyRe = RegExp(r'\b(\d{9})\b');
    final policyNumbers = <String>{};
    
    for (final line in allLines) {
      final matches = policyRe.allMatches(line);
      for (final match in matches) {
        policyNumbers.add(match.group(1)!);
      }
    }
    
    if (policyNumbers.isEmpty) {
      throw Exception('No policy numbers found in the commission PDF.');
    }
    
    // 3. Extract Summary Totals
    double totalPremium = 0;
    double totalCommission = 0;
    double netPayable = 0;
    double incomeTax = 0;

    for (final line in allLines) {
      if (line.contains('Total Premium and Commission') || line.contains('Total Premium & Commission')) {
        final matches = RegExp(r'([\d,]+\.\d{2})').allMatches(line);
        if (matches.length >= 2) {
          totalPremium =
              double.tryParse(matches.elementAt(0).group(0)!.replaceAll(',', '')) ?? 0;
          totalCommission =
              double.tryParse(matches.elementAt(1).group(0)!.replaceAll(',', '')) ?? 0;
        }
      } else if (line.contains('Income Tax')) {
        final matches = RegExp(r'([\d,]+\.\d{2})').allMatches(line);
        if (matches.isNotEmpty) {
          incomeTax =
              double.tryParse(matches.last.group(0)!.replaceAll(',', '')) ?? 0;
        }
      } else if (line.contains('Net Payable')) {
        final matches = RegExp(r'([\d,]+\.\d{2})').allMatches(line);
        if (matches.isNotEmpty) {
          netPayable =
              double.tryParse(matches.last.group(0)!.replaceAll(',', '')) ?? 0;
        }
      }
    }

    // 4. Cross-reference with Dues list
    final matchingDues = await _client
        .from('monthly_dues')
        .select('policy_number, customer_name, status')
        .eq('user_id', ownerId)
        .inFilter('policy_number', policyNumbers.toList());

    final matchedPolicies = (matchingDues as List).map((d) => d['policy_number'] as String).toSet();
    final unmatchedPoliciesInPdf = policyNumbers.where((p) => !matchedPolicies.contains(p)).toList();

    // 5. Update monthly_dues: mark as paid if policy matches
    // We update dues that are currently 'pending' or 'overdue'
    int updatedCount = 0;

    final response = await _client
        .from('monthly_dues')
        .update({
          'status': 'paid',
          'payment_date': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', ownerId)
        .inFilter('policy_number', policyNumbers.toList())
        .neq('status', 'paid') // Only update if not already paid
        .select('id');

    updatedCount = (response as List).length;

    // 6. Update commission_upload records
    await _client.from('commission_uploads').update({
      'records_count': policyNumbers.length,
      'total_premium': totalPremium,
      'total_commission': totalCommission,
      'net_payable': netPayable,
      'income_tax': incomeTax,
      'status': 'processed',
    }).eq('id', commissionUploadId);

    return {
      'success': true,
      'policy_count': policyNumbers.length,
      'marked_paid': updatedCount,
      'total_commission': totalCommission,
      'net_payable': netPayable,
      'income_tax': incomeTax,
      'matched_policies': matchedPolicies.toList(),
      'unmatched_policies': unmatchedPoliciesInPdf,
      'dues_details': matchingDues,
    };
  }

  /// Direct insert with all extracted columns.
  Future<Map<String, dynamic>> _directInsert(
    List<Map<String, dynamic>> dues,
    String pdfUploadId,
    String dueMonth, {
    String? targetUserId,
  }) async {
    final ownerId = targetUserId ?? _client.auth.currentUser!.id;
    int count = 0;

    for (final due in dues) {
      try {
        final existing = await _client
            .from('monthly_dues')
            .select('id')
            .eq('user_id', ownerId)
            .eq('policy_number', due['policy_number'])
            .eq('due_month', dueMonth)
            .maybeSingle();

        final record = {
          'user_id': ownerId,
          'pdf_upload_id': pdfUploadId,
          'policy_number': due['policy_number'],
          'customer_name': due['customer_name'],
          'premium_amount': due['premium_amount'] ?? 0,
          'gst_amount': due['gst_amount'] ?? 0,
          'total_premium': due['total_premium'] ?? 0,
          'commission_amount': due['commission_amount'] ?? 0,
          'due_month': dueMonth,
          'doc': due['doc'],
          'plan_term': due['plan_term'],
          'mode': due['mode'],
          'fup': due['fup'],
          'fig': due['fig'],
          'est_commission': due['est_commission'] ?? 0,
          'status': 'pending',
        };

        if (existing == null) {
          await _client.from('monthly_dues').insert(record);
        } else {
          record.remove('user_id');
          record.remove('status');
          await _client.from('monthly_dues').update(record).eq('id', existing['id']);
        }
        count++;
      } catch (e) {
        debugPrint('Failed to insert due ${due['policy_number']}: $e');
      }
    }

    // Try auto-matching with clients
    try {
      await _client.rpc('auto_match_dues_with_clients', params: {
        'p_user_id': ownerId,
      });
    } catch (_) {}

    await _client.from('pdf_uploads').update({
      'status': 'completed',
      'records_extracted': count,
      'processed_at': DateTime.now().toIso8601String(),
    }).eq('id', pdfUploadId);

    return {'success': true, 'records': count};
  }

  /// Extract text lines from PDF preserving row structure.
  List<String> _extractTextLines(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final allLines = <String>[];

    for (int i = 0; i < document.pages.count; i++) {
      final lines = extractor.extractTextLines(startPageIndex: i);
      for (final line in lines) {
        allLines.add(line.text.trim());
      }
    }

    document.dispose();
    return allLines;
  }

  /// Parse LIC Premium Due List format.
  /// Expected columns: S.No PolicyNo NameOfAssured D.o.C Pln/Tm Mod FUP Fig InstPrem Due GST TotPrem EstCom
  List<Map<String, dynamic>> _parseLicDueList(
      List<String> lines, String dueMonth) {
    final dues = <Map<String, dynamic>>[];
    final policyRe = RegExp(r'\b(\d{9})\b');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      // Skip header/footer/summary lines
      if (_isHeaderOrFooter(line)) continue;

      // Find policy number in the line
      final policyMatch = policyRe.firstMatch(line);
      if (policyMatch == null) continue;

      final policyNumber = policyMatch.group(1)!;

      // Parse the full row - split by whitespace
      final parsed = _parseRow(line, policyNumber, policyMatch);

      if (parsed != null) {
        parsed['due_month'] = dueMonth;
        dues.add(parsed);
      }
    }

    return dues;
  }

  bool _isHeaderOrFooter(String line) {
    final lower = line.toLowerCase();
    return lower.contains('page no') ||
        lower.contains('page total') ||
        lower.contains('grand total') ||
        lower.contains('premium due list') ||
        lower.contains('branch code') ||
        lower.contains('agent name') ||
        lower.contains('agent code') ||
        lower.contains('s.no') ||
        lower.contains('policyno') ||
        lower.contains('name of assured') ||
        lower.contains('fy -') ||
        lower.contains('st->') ||
        lower.contains('lp :') ||
        lower.contains('mt :') ||
        lower.contains('lic') ||
        lower.contains('premium :') ||
        lower.contains('g s t') ||
        lower.contains('estimated');
  }

  /// Parse a single row from the LIC PDF.
  /// Format: SNo PolicyNo Name D.o.C Pln/Tm Mod FUP Fig InstPrem Due GST TotPrem EstCom
  Map<String, dynamic>? _parseRow(
      String line, String policyNumber, Match policyMatch) {
    // Get text before and after policy number
    final beforePolicy = line.substring(0, policyMatch.start).trim();
    final afterPolicy = line.substring(policyMatch.end).trim();

    // After policy number: Name ... D.o.C Pln/Tm Mod FUP Fig InstPrem Due GST TotPrem EstCom
    // Split into tokens
    final tokens = afterPolicy.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    if (tokens.isEmpty) return null;

    // Strategy: Find the name (alphabetic chars) then parse remaining tokens
    String customerName = '';
    int dataStartIndex = 0;

    // Name can be multiple words with dots (e.g., "P ARULKUMAR", "S.SANTHIYA", "P.TAMILSELVAN")
    final nameTokens = <String>[];
    for (int j = 0; j < tokens.length; j++) {
      final token = tokens[j];
      // If token starts with a letter and is not a known abbreviation
      if (RegExp(r'^[A-Za-z]').hasMatch(token) &&
          !_isDateToken(token) &&
          !_isModeToken(token) &&
          !_isFigToken(token)) {
        nameTokens.add(token);
      } else {
        dataStartIndex = j;
        break;
      }
      if (j == tokens.length - 1) {
        dataStartIndex = tokens.length;
      }
    }
    customerName = nameTokens.join(' ');

    // Remaining tokens after name
    final dataTokens = tokens.sublist(dataStartIndex);

    // Parse data tokens
    // Expected order: D.o.C, Pln/Tm, Mod, FUP, Fig, InstPrem, Due, GST, TotPrem, EstCom
    String doc = '';
    String planTerm = '';
    String mode = '';
    String fup = '';
    String fig = '';
    double instPrem = 0;
    double due = 0;
    double gst = 0;
    double totPrem = 0;
    double estCom = 0;

    // Identify each token based on its pattern
    final dateTokens = <String>[];
    final numberTokens = <double>[];
    String modeToken = '';
    String figToken = '';
    String planTermToken = '';

    for (final token in dataTokens) {
      if (_isDateToken(token)) {
        dateTokens.add(token);
      } else if (_isModeToken(token)) {
        modeToken = token;
      } else if (_isFigToken(token)) {
        figToken = token;
      } else if (_isPlanTermToken(token)) {
        planTermToken = token;
      } else {
        // Try to parse as number
        final numVal = double.tryParse(token.replaceAll(',', ''));
        if (numVal != null) {
          numberTokens.add(numVal);
        } else {
          // Could be plan/term like "736/21" or "945/79"
          if (RegExp(r'^\d+/\d+$').hasMatch(token)) {
            planTermToken = token;
          }
        }
      }
    }

    // Assign dates: first = D.o.C, second = FUP
    if (dateTokens.isNotEmpty) doc = dateTokens[0];
    if (dateTokens.length > 1) fup = dateTokens[1];

    // Mode
    mode = modeToken;

    // Fig
    fig = figToken;

    // Plan/Term
    planTerm = planTermToken;

    // Numbers: InstPrem, Due, GST, TotPrem, EstCom
    if (numberTokens.length >= 5) {
      instPrem = numberTokens[0];
      due = numberTokens[1];
      gst = numberTokens[2];
      totPrem = numberTokens[3];
      estCom = numberTokens[4];
    } else if (numberTokens.length == 4) {
      instPrem = numberTokens[0];
      due = numberTokens[1];
      gst = numberTokens[2];
      totPrem = numberTokens[3];
    } else if (numberTokens.length == 3) {
      instPrem = numberTokens[0];
      gst = numberTokens[1];
      totPrem = numberTokens[2];
    } else if (numberTokens.length == 2) {
      instPrem = numberTokens[0];
      totPrem = numberTokens[1];
    } else if (numberTokens.length == 1) {
      instPrem = numberTokens[0];
      totPrem = numberTokens[0];
    }

    return {
      'policy_number': policyNumber,
      'customer_name': customerName.isNotEmpty ? customerName : null,
      'doc': doc.isNotEmpty ? doc : null,
      'plan_term': planTerm.isNotEmpty ? planTerm : null,
      'mode': mode.isNotEmpty ? mode : null,
      'fup': fup.isNotEmpty ? fup : null,
      'fig': fig.isNotEmpty ? fig : null,
      'premium_amount': instPrem,
      'gst_amount': gst,
      'total_premium': totPrem > 0 ? totPrem : instPrem,
      'commission_amount': due,
      'est_commission': estCom,
    };
  }

  bool _isDateToken(String token) {
    // Matches DD/MM/YYYY or MM/YYYY or DD/MM/YY
    return RegExp(r'^\d{1,2}/\d{1,2}/?\d{2,4}$').hasMatch(token) ||
        RegExp(r'^\d{2}/\d{4}$').hasMatch(token);
  }

  bool _isModeToken(String token) {
    final t = token.toLowerCase();
    return t == 'hly' || t == 'qly' || t == 'mly' || t == 'yly' ||
        t == 'half' || t == 'quarterly' || t == 'monthly' || t == 'yearly';
  }

  bool _isFigToken(String token) {
    final t = token.toUpperCase();
    return t == 'FY' || t == 'ST' || t == 'LP' || t == 'MT';
  }

  bool _isPlanTermToken(String token) {
    return RegExp(r'^\d{3}/\d{2}$').hasMatch(token);
  }
}
