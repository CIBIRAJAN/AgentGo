/// Model for a commission record generated when a due is marked paid.
class CommissionModel {
  final String id;
  final String userId;
  final String? dueId;
  final String? clientId;
  final String policyNumber;
  final double commissionAmount;
  final String commissionMonth;
  final String? commissionType; // first_year, renewal, bonus
  final String? status; // pending, received, not_received
  final DateTime createdAt;

  const CommissionModel({
    required this.id,
    required this.userId,
    this.dueId,
    this.clientId,
    required this.policyNumber,
    this.commissionAmount = 0,
    required this.commissionMonth,
    this.commissionType = 'renewal',
    this.status = 'pending',
    required this.createdAt,
  });

  factory CommissionModel.fromJson(Map<String, dynamic> json) {
    return CommissionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dueId: json['due_id'] as String?,
      clientId: json['client_id'] as String?,
      policyNumber: json['policy_number'] as String,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      commissionMonth: json['commission_month'] as String,
      commissionType: json['commission_type'] as String?,
      status: json['status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
