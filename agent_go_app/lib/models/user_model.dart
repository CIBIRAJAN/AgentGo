/// Model representing the LIC agent (app user).
class UserModel {
  final String id;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? profile;
  final String? agentCode;
  final bool notification;
  final String status;
  final String subscriptionStatus;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    this.name,
    this.email,
    this.phoneNumber,
    this.profile,
    this.agentCode,
    this.notification = false,
    this.status = 'active',
    this.subscriptionStatus = 'none',
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      profile: json['profile'] as String?,
      agentCode: json['agent_code'] as String?,
      notification: json['notification'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      subscriptionStatus: json['subscription_status'] as String? ?? 'none',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone_number': phoneNumber,
        'profile': profile,
        'agent_code': agentCode,
        'notification': notification,
        'status': status,
        'subscription_status': subscriptionStatus,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? profile,
    String? agentCode,
    bool? notification,
    String? status,
    String? subscriptionStatus,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profile: profile ?? this.profile,
      agentCode: agentCode ?? this.agentCode,
      notification: notification ?? this.notification,
      status: status ?? this.status,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      createdAt: createdAt,
    );
  }
}
