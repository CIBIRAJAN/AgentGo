import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AutoCallService {
  // Replace this with your generated n8n Webhook URL
  static const String _n8nWebhookUrl = 'https://primary-production-93e5.up.railway.app/webhook/vapi-outbound-call';

  /// Trigger an AI auto-call via n8n integration
  static Future<bool> triggerAutoCall({
    required String clientName,
    required String phoneNumber,
    required String policyNumber,
    required double amountDue,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final agentName = user?.userMetadata?['full_name'] ?? 'AgentGo Representative';

      final response = await http.post(
        Uri.parse(_n8nWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'agent_name': agentName,
          'client_name': clientName,
          'phone_number': phoneNumber, // Must include country code, e.g. +91XXXXXXXXXX
          'policy_number': policyNumber,
          'amount_due': amountDue.toStringAsFixed(2),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
