/// Model for a monthly premium due extracted from the LIC PDF.
class MonthlyDueModel {
  final String id;
  final String userId;
  final String? clientId;
  final String? pdfUploadId;
  final String policyNumber;
  final String? customerName;
  final double premiumAmount;
  final double gstAmount;
  final double totalPremium;
  final double commissionAmount;
  final String dueMonth;
  final DateTime? dueDate;
  final String status; // pending, paid, overdue, lapsed
  final DateTime? paymentDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional joined fields
  final String? clientName;
  final String? clientPhone;
  final String? clientMode;
  final String? clientPhoneCc;
  final String? clientEmail;

  const MonthlyDueModel({
    required this.id,
    required this.userId,
    this.clientId,
    this.pdfUploadId,
    required this.policyNumber,
    this.customerName,
    this.premiumAmount = 0,
    this.gstAmount = 0,
    this.totalPremium = 0,
    this.commissionAmount = 0,
    required this.dueMonth,
    this.dueDate,
    this.status = 'pending',
    this.paymentDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.clientName,
    this.clientPhone,
    this.clientMode,
    this.clientPhoneCc,
    this.clientEmail,
  });

  factory MonthlyDueModel.fromJson(Map<String, dynamic> json) {
    return MonthlyDueModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      clientId: json['client_id'] as String?,
      pdfUploadId: json['pdf_upload_id'] as String?,
      policyNumber: json['policy_number'] as String,
      customerName: json['customer_name'] as String?,
      premiumAmount: _toDouble(json['premium_amount']),
      gstAmount: _toDouble(json['gst_amount']),
      totalPremium: _toDouble(json['total_premium']),
      commissionAmount: _toDouble(json['commission_amount']),
      dueMonth: json['due_month'] as String,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      clientName: json['client_name'] as String?,
      clientPhone: json['client_phone'] as String?,
      clientMode: json['client_mode'] as String?,
      clientPhoneCc: json['client_phone_cc'] as String?,
      clientEmail: json['client_email'] as String?,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';
  bool get isLapsed => status == 'lapsed';

  /// Display name: prefer customer_name, fall back to client_name
  String get displayName => customerName ?? clientName ?? 'Unknown';
}
