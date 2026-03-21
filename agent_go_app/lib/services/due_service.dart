import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/monthly_due_model.dart';

/// Manages monthly due operations.
class DueService {
  final SupabaseClient _client;
  final List<String> _targetUserIds;

  DueService(this._client, {List<String>? targetUserIds})
      : _targetUserIds = targetUserIds ?? [_client.auth.currentUser!.id];

  String get _userId => _client.auth.currentUser!.id;

  /// Get dues with optional filters.
  Future<List<MonthlyDueModel>> getDues({
    String? dueMonth,
    String? status,
    String? clientId,
    int limit = 3000,
    int offset = 0,
  }) async {
    var query = _client.from('monthly_dues').select('''
      *,
      client:client_id (full_name, mobile_number, mobile_number_cc, "Mode", email)
    ''').inFilter('user_id', _targetUserIds);

    if (dueMonth != null) query = query.eq('due_month', dueMonth);
    if (status != null) query = query.eq('status', status);
    if (clientId != null) query = query.eq('client_id', clientId);

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      // Flatten joined client data
      if (map['client'] != null && map['client'] is Map) {
        map['client_name'] = map['client']['full_name'];
        map['client_phone'] = map['client']['mobile_number'];
        map['client_phone_cc'] = map['client']['mobile_number_cc'];
        map['client_mode'] = map['client']['Mode'];
        map['client_email'] = map['client']['email'];
      }
      return MonthlyDueModel.fromJson(map);
    }).toList();
  }

  /// Get a single due by ID.
  Future<MonthlyDueModel?> getDue(String dueId) async {
    final response = await _client.from('monthly_dues').select('''
      *,
      client:client_id (full_name, mobile_number, mobile_number_cc, email)
    ''').eq('id', dueId).inFilter('user_id', _targetUserIds).maybeSingle();

    if (response == null) return null;
    final map = Map<String, dynamic>.from(response);
    if (map['client'] != null && map['client'] is Map) {
      map['client_name'] = map['client']['full_name'];
      map['client_phone'] = map['client']['mobile_number'];
      map['client_phone_cc'] = map['client']['mobile_number_cc'];
      map['client_email'] = map['client']['email'];
    }
    return MonthlyDueModel.fromJson(map);
  }

  /// Mark a due as paid (uses RPC for transactional operation).
  Future<Map<String, dynamic>> markAsPaid(String dueId, {String? notes}) async {
    // Transactional logic on DB might need check for permissions
    final response = await _client.rpc('mark_due_as_paid', params: {
      'p_user_id': _userId, // The person doing the action
      'p_due_id': dueId,
      'p_notes': notes,
    });
    return response as Map<String, dynamic>;
  }

  /// Get overdue clients.
  Future<List<Map<String, dynamic>>> getOverdueClients() async {
    final response = await _client.rpc('get_overdue_clients', params: {
      'p_user_id': _targetUserIds.first, // Fallback to first selected for now
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Get client dues summary (total owed by each client).
  Future<List<Map<String, dynamic>>> getClientDuesSummary(
      {String? dueMonth}) async {
    final response = await _client.rpc('get_client_dues_summary', params: {
      'p_user_id': _targetUserIds.first,
      'p_due_month': dueMonth,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Update due status manually.
  Future<void> updateDueStatus(String dueId, String status) async {
    await _client.from('monthly_dues').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', dueId).inFilter('user_id', _targetUserIds);
  }

  /// Get unique due months for filtering.
  Future<List<String>> getAvailableMonths() async {
    final response = await _client
        .from('monthly_dues')
        .select('due_month')
        .inFilter('user_id', _targetUserIds)
        .order('due_month', ascending: false);

    final months = <String>{};
    for (final row in response as List) {
      if (row['due_month'] != null) {
        months.add(row['due_month'] as String);
      }
    }
    return months.toList();
  }
}
