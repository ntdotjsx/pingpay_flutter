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
  final String? displayName;
  final String? avatarUrl;
  final String? role;
  final OnboardingState onboardingState;

  UserModel({
    required this.id,
    this.userCode,
    this.displayName,
    this.avatarUrl,
    this.role,
    this.onboardingState = OnboardingState.unknown,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['userId'] ?? json['id'] ?? '',
      userCode: json['userCode'],
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'user',
      onboardingState: OnboardingState.fromString(json['onboardingState']),
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
