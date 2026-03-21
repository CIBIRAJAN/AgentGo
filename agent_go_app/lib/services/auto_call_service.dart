import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AutoCallService {
  // Replace this with your generated n8n Webhook URL
  static const String _n8nWebhookUrl = 'http://localhost:5678/webhook/f776e1ea-c12c-4fc2-b4b8-ef0d7201e649';

  /// Trigger an AI auto-call via n8n integration
  static Future<bool> triggerAutoCall({
    required String clientName,
    required String phoneNumber,
    required String policyNumber,
    required double amountDue,
    required String dueMonth,
    String? clientId,
    String? dueId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final agentName = user?.userMetadata?['full_name'] ?? 'AgentGo Representative';

      // 1. Create a log entry first
      String? logId;
      try {
        final logData = await client.from('call_logs').insert({
          'user_id': user?.id,
          'client_id': clientId,
          'due_id': dueId,
          'phone_number': phoneNumber,
          'policy_number': policyNumber,
          'status': 'initiated',
        }).select('id').single();
        logId = logData['id'];
      } catch (e) {
        // Silently continue if logging fails
      }

      final response = await http.post(
        Uri.parse(_n8nWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'call_log_id': logId,
          'agent_name': agentName,
          'client_name': clientName,
          'phone_number': phoneNumber,
          'policy_number': policyNumber,
          'amount_due': amountDue.toStringAsFixed(2),
          'pending_due_month': dueMonth,
        }),
      );

      bool success = response.statusCode >= 200 && response.statusCode < 300;

      // 2. Update log if request failed immediately
      if (!success && logId != null) {
        await client.from('call_logs').update({
          'status': 'failed',
          'error_reason': 'Webhook trigger failed (Status: ${response.statusCode})',
        }).eq('id', logId);
      }

      return success;
    } catch (e) {
      return false;
    }
  }
}
