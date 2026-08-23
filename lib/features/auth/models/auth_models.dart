enum OnboardingState {
  pdpaRequired,
  profileRequired,
  pinRequired,
  completed,
  unknown;

  static OnboardingState fromString(String? val) {
    switch (val) {
      case 'PDPA_REQUIRED':
        return OnboardingState.pdpaRequired;
      case 'PROFILE_REQUIRED':
        return OnboardingState.profileRequired;
      case 'PIN_REQUIRED':
        return OnboardingState.pinRequired;
      case 'COMPLETED':
        return OnboardingState.completed;
      default:
        return OnboardingState.unknown;
    }
  }
}

class UserModel {
  final String id;
  final String? userCode;
  final String? email;
  final String? displayName;
  final String? fullName;
  final String? avatarUrl;
  final String? role;
  final String? promptPayId;
  final String? phoneNumber;
  final String? bankAccountNumber;
  final int rewardPoints;
  final String? shippingAddress;
  final String? shippingPhone;
  final String? shippingRecipientName;
  final OnboardingState onboardingState;
  final bool isLineFriend;

  UserModel({
    required this.id,
    this.userCode,
    this.email,
    this.displayName,
    this.fullName,
    this.avatarUrl,
    this.role,
    this.promptPayId,
    this.phoneNumber,
    this.bankAccountNumber,
    this.rewardPoints = 27,
    this.shippingAddress,
    this.shippingPhone,
    this.shippingRecipientName,
    this.onboardingState = OnboardingState.unknown,
    this.isLineFriend = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['userId'] ?? json['id'] ?? '',
      userCode: json['userCode'],
      email: json['email'],
      displayName: json['displayName'],
      fullName: json['fullName'],
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'user',
      promptPayId: json['promptPayId'],
      phoneNumber: json['phoneNumber'],
      bankAccountNumber: json['bankAccountNumber'],
      rewardPoints: json['rewardPoints'] is int
          ? json['rewardPoints'] as int
          : (int.tryParse(json['rewardPoints']?.toString() ?? '27') ?? 27),
      shippingAddress: json['shippingAddress'],
      shippingPhone: json['shippingPhone'],
      shippingRecipientName: json['shippingRecipientName'],
      onboardingState: OnboardingState.fromString(json['onboardingState']),
      isLineFriend: json['isLineFriend'] == true,
    );
  }
}

class PdpaConsentModel {
  final String policyVersion;
  final bool hasAccepted;
  final String? lastAcceptedAt;

  PdpaConsentModel({
    required this.policyVersion,
    required this.hasAccepted,
    this.lastAcceptedAt,
  });

  factory PdpaConsentModel.fromJson(Map<String, dynamic> json) {
    return PdpaConsentModel(
      policyVersion: json['policyVersion'] ?? 'v1.0.0',
      hasAccepted: json['hasAccepted'] ?? false,
      lastAcceptedAt: json['lastAcceptedAt'],
    );
  }
}
