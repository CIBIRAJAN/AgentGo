class AgentDiaryModel {
  final String id;
  final String userId;
  final String name;
  final String? phoneNumber;
  final String? address;
  final DateTime? appointmentDate1;
  final DateTime? appointmentDate2;
  final DateTime? appointmentDate3;
  final DateTime createdAt;

  AgentDiaryModel({
    required this.id,
    required this.userId,
    required this.name,
    this.phoneNumber,
    this.address,
    this.appointmentDate1,
    this.appointmentDate2,
    this.appointmentDate3,
    required this.createdAt,
  });

  factory AgentDiaryModel.fromJson(Map<String, dynamic> json) {
    return AgentDiaryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String?,
      address: json['address'] as String?,
      appointmentDate1: json['appointment_date_1'] != null ? DateTime.parse(json['appointment_date_1'] as String) : null,
      appointmentDate2: json['appointment_date_2'] != null ? DateTime.parse(json['appointment_date_2'] as String) : null,
      appointmentDate3: json['appointment_date_3'] != null ? DateTime.parse(json['appointment_date_3'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'appointment_date_1': appointmentDate1?.toIso8601String(),
      'appointment_date_2': appointmentDate2?.toIso8601String(),
      'appointment_date_3': appointmentDate3?.toIso8601String(),
    };
  }
}
