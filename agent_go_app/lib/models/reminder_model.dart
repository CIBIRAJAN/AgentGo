/// Model for a reminder sent to a client about a due.
class ReminderModel {
  final String id;
  final String userId;
  final String? dueId;
  final String? clientId;
  final String? policyNumber;
  final String reminderType; // whatsapp, call, sms, email
  final String status; // pending, sent, failed, delivered
  final String? messageContent;
  final DateTime? sentAt;
  final DateTime createdAt;

  // Optional joined fields
  final String? clientName;
  final String? clientPhone;
  final double? totalPremium;
  final String? dueMonth;

  const ReminderModel({
    required this.id,
    required this.userId,
    this.dueId,
    this.clientId,
    this.policyNumber,
    required this.reminderType,
    this.status = 'sent',
    this.messageContent,
    this.sentAt,
    required this.createdAt,
    this.clientName,
    this.clientPhone,
    this.totalPremium,
    this.dueMonth,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dueId: json['due_id'] as String?,
      clientId: json['client_id'] as String?,
      policyNumber: json['policy_number'] as String?,
      reminderType: json['reminder_type'] as String,
      status: json['status'] as String? ?? 'sent',
      messageContent: json['message_content'] as String?,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      clientName: json['client_name'] as String?,
      clientPhone: json['client_phone'] as String?,
      totalPremium: json['total_premium'] != null
          ? (json['total_premium'] as num).toDouble()
          : null,
      dueMonth: json['due_month'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'due_id': dueId,
        'client_id': clientId,
        'policy_number': policyNumber,
        'reminder_type': reminderType,
        'status': status,
        'message_content': messageContent,
      };
}
