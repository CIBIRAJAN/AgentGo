import 'package:url_launcher/url_launcher.dart';

/// Helper for launching phone calls, WhatsApp, and URLs.
class UrlLauncherHelper {
  UrlLauncherHelper._();

  /// Make a phone call.
  static Future<bool> makeCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Open WhatsApp with a pre-filled message.
  static Future<bool> openWhatsApp({
    required String phoneNumber,
    String? message,
  }) async {
    // Remove spaces and special characters, keep + and digits
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\+\d]'), '');

    final uri = Uri.parse(
      'https://wa.me/$cleanNumber${message != null ? '?text=${Uri.encodeComponent(message)}' : ''}',
    );

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Send an SMS.
  static Future<bool> sendSms(String phoneNumber, {String? body}) async {
    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: body != null ? {'body': body} : null,
    );
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Send an email.
  static Future<bool> sendEmail(String email, {String? subject, String? body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      }.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
    );
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Generate a default premium reminder message.
  static String premiumReminderMessage({
    required String clientName,
    required String policyNumber,
    required String amount,
    required String dueMonth,
  }) {
    return '''Dear $clientName,

This is a friendly reminder that your LIC premium is due.

Policy No: $policyNumber
Amount: $amount
Due Month: $dueMonth

Please pay your premium at the earliest to keep your policy active.

Thank you!''';
  }
}
