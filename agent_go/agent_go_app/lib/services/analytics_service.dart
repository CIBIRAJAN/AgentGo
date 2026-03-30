import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides analytics data from Supabase RPC functions.
class AnalyticsService {
  final SupabaseClient _client;
  final List<String> _targetUserIds;

  AnalyticsService(this._client, {List<String>? targetUserIds})
      : _targetUserIds = targetUserIds ?? [_client.auth.currentUser!.id];

  String get _userId => _client.auth.currentUser!.id;

  /// Get dashboard summary for a given month.
  Future<Map<String, dynamic>> getDashboardSummary(String dueMonth) async {
    final response = await _client.rpc('get_dashboard_summary', params: {
      'p_user_ids': _targetUserIds,
      'p_due_month': dueMonth,
    });
    return response as Map<String, dynamic>;
  }

  /// Get commission analytics (monthly trend).
  Future<List<Map<String, dynamic>>> getCommissionAnalytics(
      {int months = 6}) async {
    final response = await _client.rpc('get_commission_analytics_v2', params: {
      'p_user_ids': _targetUserIds,
      'p_months': months,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Get payment behavior of customers (who pays late).
  Future<List<Map<String, dynamic>>> getPaymentBehavior(
      {int limit = 20}) async {
    final response = await _client.rpc('get_payment_behavior', params: {
      'p_user_id': _targetUserIds.first,
      'p_limit': limit,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Get call statistics (responded vs failed).
  Future<Map<String, int>> getCallStats() async {
    final completed = await _client
        .from('call_logs')
        .select('*')
        .filter('user_id', 'in', _targetUserIds)
        .eq('status', 'completed');

    final failed = await _client
        .from('call_logs')
        .select('*')
        .filter('user_id', 'in', _targetUserIds)
        .neq('status', 'completed')
        .neq('status', 'initiated');

    return {
      'completed': (completed as List).length,
      'failed': (failed as List).length,
    };
  }

  /// Get call logs for a specific status.
  Future<List<Map<String, dynamic>>> getCallLogDetails(bool successful) async {
    var query = _client
        .from('call_logs')
        .select('*, client:client_id(full_name)')
        .filter('user_id', 'in', _targetUserIds);

    if (successful) {
      query = query.eq('status', 'completed');
    } else {
      query = query.neq('status', 'completed').neq('status', 'initiated');
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }
}
