enum OnboardingStep {
  profile,
  migration,
  payment,
  completed;

  String get value => name;

  static OnboardingStep fromString(String val) {
    return OnboardingStep.values.firstWhere(
      (step) => step.name == val,
      orElse: () => OnboardingStep.profile,
    );
  }
}

/// Model representing the LIC agent (app user).
class UserModel {
  final String id;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? profile;
  final String? agentCode;
  final String? dob;
  final bool notification;
  final String status;
  final String subscriptionStatus;
  final String planTier; // 'base', 'mid', 'premium' 
  final int callPointsBalance;
  final int freeCallsUsedThisMonth;
  final bool isWalletBlocked;
  final OnboardingStep onboardingStep;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    this.name,
    this.email,
    this.phoneNumber,
    this.profile,
    this.agentCode,
    this.dob,
    this.notification = false,
    this.status = 'active',
    this.subscriptionStatus = 'none',
    this.planTier = 'base',
    this.callPointsBalance = 0,
    this.freeCallsUsedThisMonth = 0,
    this.isWalletBlocked = false,
    this.onboardingStep = OnboardingStep.profile,
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
      dob: json['dob'] as String?,
      notification: json['notification'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      subscriptionStatus: json['subscription_status'] as String? ?? 'none',
      planTier: json['plan_tier'] as String? ?? 'base',
      callPointsBalance: json['call_points_balance'] as int? ?? 0,
      freeCallsUsedThisMonth: json['free_calls_used_this_month'] as int? ?? 0,
      isWalletBlocked: json['is_wallet_blocked'] as bool? ?? false,
      onboardingStep: OnboardingStep.fromString(json['onboarding_step'] as String? ?? 'profile'),
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
        'dob': dob,
        'notification': notification,
        'status': status,
        'subscription_status': subscriptionStatus,
        'plan_tier': planTier,
        'call_points_balance': callPointsBalance,
        'free_calls_used_this_month': freeCallsUsedThisMonth,
        'is_wallet_blocked': isWalletBlocked,
        'onboarding_step': onboardingStep.name,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? profile,
    String? agentCode,
    String? dob,
    bool? notification,
    String? status,
    String? subscriptionStatus,
    String? planTier,
    int? callPointsBalance,
    int? freeCallsUsedThisMonth,
    bool? isWalletBlocked,
    OnboardingStep? onboardingStep,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profile: profile ?? this.profile,
      agentCode: agentCode ?? this.agentCode,
      dob: dob ?? this.dob,
      notification: notification ?? this.notification,
      status: status ?? this.status,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      planTier: planTier ?? this.planTier,
      callPointsBalance: callPointsBalance ?? this.callPointsBalance,
      freeCallsUsedThisMonth: freeCallsUsedThisMonth ?? this.freeCallsUsedThisMonth,
      isWalletBlocked: isWalletBlocked ?? this.isWalletBlocked,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      createdAt: createdAt,
    );
  }
}
