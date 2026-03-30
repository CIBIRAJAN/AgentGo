import 'package:flutter/material.dart';

class AggregatedDueModel {
  final String policyNumber;
  final String customerName;
  final String? clientId;
  final double totalPremium;
  final double premiumAmount;
  final int unpaidMonthsCount;
  final String unpaidMonthsList;
  final String? mobileNumber;
  final String? mobileNumberCc;
  final String? email;
  final String status;

  AggregatedDueModel({
    required this.policyNumber,
    required this.customerName,
    this.clientId,
    required this.totalPremium,
    required this.premiumAmount,
    required this.unpaidMonthsCount,
    required this.unpaidMonthsList,
    this.mobileNumber,
    this.mobileNumberCc,
    this.email,
    required this.status,
  });

  factory AggregatedDueModel.fromJson(Map<String, dynamic> json) {
    return AggregatedDueModel(
      policyNumber: json['policy_number']?.toString() ?? 'N/A',
      customerName: json['customer_name']?.toString() ?? 'Unknown',
      clientId: json['client_id']?.toString(),
      totalPremium: _toDouble(json['total_premium']),
      premiumAmount: _toDouble(json['premium_amount']),
      unpaidMonthsCount: (json['unpaid_months_count'] as num? ?? 0).toInt(),
      unpaidMonthsList: json['unpaid_months_list']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString(),
      mobileNumberCc: json['mobile_number_cc']?.toString(),
      email: json['email']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String get displayName => customerName;

  bool get isPending => status?.toLowerCase() == 'pending';
  bool get isPaid => status?.toLowerCase() == 'paid';
  bool get isOverdue => status?.toLowerCase() == 'overdue';
  bool get isLapsed => status?.toLowerCase() == 'lapsed';
}
