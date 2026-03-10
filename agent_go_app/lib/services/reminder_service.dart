import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder_model.dart';

/// Manages reminder tracking and automated call triggers.
class ReminderService {
  final SupabaseClient _client;
  final List<String> _targetUserIds;

  ReminderService(this._client, {List<String>? targetUserIds})
      : _targetUserIds = targetUserIds ?? [_client.auth.currentUser!.id];

  String get _userId => _client.auth.currentUser!.id;

  /// Log a manual reminder (call, whatsapp, sms).
  Future<void> logReminder({
    required String reminderType,
    String? dueId,
    String? clientId,
    String? policyNumber,
    String? messageContent,
    String callType = 'manual',
  }) async {
    await _client.from('reminders').insert({
      'user_id': _userId,
      'due_id': dueId,
      'client_id': clientId,
      'policy_number': policyNumber,
      'reminder_type': reminderType,
      'call_type': callType,
      'status': 'sent',
      'message_content': messageContent,
      'sent_at': DateTime.now().toIso8601String(),
    });
  }

  /// Trigger an automated reminder call via the Edge Function.
  /// The Edge Function creates a reminder record AND triggers n8n/Twilio.
  Future<Map<String, dynamic>> sendAutoCall({
    required String customerName,
    required String phoneNumber,
    String? phoneCc,
    String? dueId,
    String? clientId,
    String? policyNumber,
    double? premiumAmount,
    double? totalPremium,
    String? dueMonth,
  }) async {
    final response = await _client.functions.invoke(
      'send-reminder-call',
      body: {
        'user_id': _userId,
        'due_id': dueId,
        'client_id': clientId,
        'policy_number': policyNumber,
        'customer_name': customerName,
        'phone_number': phoneNumber,
        'phone_cc': phoneCc ?? '+91',
        'premium_amount': premiumAmount,
        'total_premium': totalPremium,
        'due_month': dueMonth,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  /// Retry auto calls for all failed reminders this month.
  Future<List<Map<String, dynamic>>> getFailedCallReminders() async {
    final response = await _client.rpc('get_failed_call_reminders', params: {
      'p_user_id': _userId,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Get reminder counts for the dashboard.
  Future<Map<String, dynamic>> getReminderCounts({String? dueMonth}) async {
    final response = await _client.rpc('get_reminder_counts', params: {
      'p_user_ids': _targetUserIds,
      'p_due_month': dueMonth,
    });
    return response as Map<String, dynamic>;
  }

  /// Get reminder history for a client or due.
  Future<List<ReminderModel>> getReminderHistory({
    String? clientId,
    String? dueId,
  }) async {
    var query =
        _client.from('reminders').select().inFilter('user_id', _targetUserIds);

    if (clientId != null) query = query.eq('client_id', clientId);
    if (dueId != null) query = query.eq('due_id', dueId);

    final response = await query.order('created_at', ascending: false).limit(50);

    return (response as List).map((e) => ReminderModel.fromJson(e)).toList();
  }

  /// Update a reminder status (used by n8n callback).
  Future<void> updateReminderStatus(String reminderId, String status,
      {String? callSid}) async {
    final updates = <String, dynamic>{'status': status};
    if (callSid != null) updates['call_sid'] = callSid;
    await _client
        .from('reminders')
        .update(updates)
        .eq('id', reminderId)
        .eq('user_id', _userId);
  }
}
