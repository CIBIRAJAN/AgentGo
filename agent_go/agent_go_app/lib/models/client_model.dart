/// Model representing a client (customer) of the LIC agent.
class ClientModel {
  final String id;
  final String? userId;
  final String? fullName;
  final String? policyNumber;
  final String? sum;
  final String? plan;
  final String? time;
  final String? mode;
  final String? amount;
  final DateTime? dateOfCommission;
  final String? address;
  final String? mobileNumber;
  final String? mobileNumberCc;
  final DateTime? dateOfBirth;
  final String? profilePicture;
  final String? profileImageUrl;
  final bool? notification;
  final DateTime? weddingAnniversary;
  final DateTime? policyStartDate;
  final DateTime? policyEndDate;
  final String? term;
  final String? email;
  final String? premium;
  final String? nominee;
  final String? ownerName; // Added
  final DateTime createdAt;

  const ClientModel({
    required this.id,
    this.userId,
    this.fullName,
    this.policyNumber,
    this.sum,
    this.plan,
    this.time,
    this.mode,
    this.amount,
    this.dateOfCommission,
    this.address,
    this.mobileNumber,
    this.mobileNumberCc,
    this.dateOfBirth,
    this.profilePicture,
    this.profileImageUrl,
    this.notification,
    this.weddingAnniversary,
    this.policyStartDate,
    this.policyEndDate,
    this.term,
    this.email,
    this.premium,
    this.nominee,
    this.ownerName, // Added
    required this.createdAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      fullName: json['full_name'] as String?,
      policyNumber: json['Policy_Number'] as String?,
      sum: json['Sum'] as String?,
      plan: json['Plan'] as String?,
      time: json['Time'] as String?,
      mode: json['Mode'] as String?,
      amount: json['Amount'] as String?,
      dateOfCommission: json['Date of commision'] != null
          ? DateTime.tryParse(json['Date of commision'] as String)
          : null,
      address: json['Address'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      mobileNumberCc: json['mobile_number_cc'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
      profilePicture: json['profile_picture'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      notification: json['notification?'] as bool?,
      weddingAnniversary: json['wedding anniversary'] != null
          ? DateTime.tryParse(json['wedding anniversary'] as String)
          : null,
      policyStartDate: json['policy_start_date'] != null
          ? DateTime.tryParse(json['policy_start_date'] as String)
          : null,
      policyEndDate: json['policy_end_date'] != null
          ? DateTime.tryParse(json['policy_end_date'] as String)
          : null,
      term: json['Term'] as String?,
      email: json['email'] as String?,
      premium: json['Premium'] as String?,
      nominee: json['nominee'] as String?,
      ownerName: json['user']?['name'] as String?, // From join
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'full_name': fullName,
        'Policy_Number': policyNumber,
        'Sum': sum,
        'Plan': plan,
        'Time': time,
        'Mode': mode,
        'Amount': amount,
        'Date of commision': dateOfCommission?.toIso8601String().split('T').first,
        'Address': address,
        'mobile_number': mobileNumber,
        'mobile_number_cc': mobileNumberCc,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'profile_picture': profilePicture,
        'profile_image_url': profileImageUrl,
        'notification?': notification,
        'wedding anniversary':
            weddingAnniversary?.toIso8601String().split('T').first,
        'policy_start_date': policyStartDate?.toIso8601String().split('T').first,
        'policy_end_date': policyEndDate?.toIso8601String().split('T').first,
        'Term': term,
        'email': email,
        'Premium': premium,
        'nominee': nominee,
      };

  /// Helper: full phone number with country code.
  String get fullPhoneNumber {
    final cc = mobileNumberCc ?? '+91';
    return '$cc${mobileNumber ?? ''}';
  }

  ClientModel copyWith({
    String? fullName,
    String? policyNumber,
    String? sum,
    String? plan,
    String? time,
    String? mode,
    String? amount,
    DateTime? dateOfCommission,
    String? address,
    String? mobileNumber,
    String? mobileNumberCc,
    DateTime? dateOfBirth,
    String? profilePicture,
    String? profileImageUrl,
    bool? notification,
    DateTime? weddingAnniversary,
    DateTime? policyStartDate,
    DateTime? policyEndDate,
    String? term,
    String? email,
    String? premium,
    String? nominee,
  }) {
    return ClientModel(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      policyNumber: policyNumber ?? this.policyNumber,
      sum: sum ?? this.sum,
      plan: plan ?? this.plan,
      time: time ?? this.time,
      mode: mode ?? this.mode,
      amount: amount ?? this.amount,
      dateOfCommission: dateOfCommission ?? this.dateOfCommission,
      address: address ?? this.address,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      mobileNumberCc: mobileNumberCc ?? this.mobileNumberCc,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profilePicture: profilePicture ?? this.profilePicture,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      notification: notification ?? this.notification,
      weddingAnniversary: weddingAnniversary ?? this.weddingAnniversary,
      policyStartDate: policyStartDate ?? this.policyStartDate,
      policyEndDate: policyEndDate ?? this.policyEndDate,
      term: term ?? this.term,
      email: email ?? this.email,
      premium: premium ?? this.premium,
      nominee: nominee ?? this.nominee,
      createdAt: createdAt,
    );
  }
}
