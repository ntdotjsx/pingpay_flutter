class FriendUserModel {
  final String? id;
  final String userCode;
  final String displayName;
  final String? avatarUrl;

  const FriendUserModel({
    this.id,
    required this.userCode,
    required this.displayName,
    this.avatarUrl,
  });

  factory FriendUserModel.fromJson(Map<String, dynamic> json) {
    return FriendUserModel(
      id: json['id'] as String?,
      userCode: json['userCode'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'ผู้ใช้งาน',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'userCode': userCode,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };
}

class FriendItemModel {
  final String friendshipId;
  final DateTime friendsSince;
  final FriendUserModel user;

  const FriendItemModel({
    required this.friendshipId,
    required this.friendsSince,
    required this.user,
  });

  factory FriendItemModel.fromJson(Map<String, dynamic> json) {
    return FriendItemModel(
      friendshipId: json['friendshipId'] as String? ?? '',
      friendsSince: json['friendsSince'] != null
          ? DateTime.tryParse(json['friendsSince'].toString()) ?? DateTime.now()
          : DateTime.now(),
      user: FriendUserModel.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'friendshipId': friendshipId,
    'friendsSince': friendsSince.toIso8601String(),
    'user': user.toJson(),
  };
}

class FriendRequestItemModel {
  final String requestId;
  final DateTime createdAt;
  final FriendUserModel user;

  const FriendRequestItemModel({
    required this.requestId,
    required this.createdAt,
    required this.user,
  });

  factory FriendRequestItemModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestItemModel(
      requestId: json['requestId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      user: FriendUserModel.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'createdAt': createdAt.toIso8601String(),
    'user': user.toJson(),
  };
}

enum RelationshipState {
  self,
  none,
  outgoingRequest,
  incomingRequest,
  friend,
  blocked;

  static RelationshipState fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'SELF':
        return RelationshipState.self;
      case 'OUTGOING_REQUEST':
        return RelationshipState.outgoingRequest;
      case 'INCOMING_REQUEST':
        return RelationshipState.incomingRequest;
      case 'FRIEND':
        return RelationshipState.friend;
      case 'BLOCKED':
        return RelationshipState.blocked;
      default:
        return RelationshipState.none;
    }
  }
}

class UserSearchModel {
  final String userCode;
  final String displayName;
  final String? avatarUrl;
  final RelationshipState relationship;

  const UserSearchModel({
    required this.userCode,
    required this.displayName,
    this.avatarUrl,
    required this.relationship,
  });

  factory UserSearchModel.fromJson(Map<String, dynamic> json) {
    return UserSearchModel(
      userCode: json['userCode'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'ผู้ใช้งาน',
      avatarUrl: json['avatarUrl'] as String?,
      relationship: RelationshipState.fromString(
        json['relationship'] as String?,
      ),
    );
  }
}

class OutstandingDebtDetails {
  final String youOweFriend;
  final String friendOwesYou;

  const OutstandingDebtDetails({
    required this.youOweFriend,
    required this.friendOwesYou,
  });

  factory OutstandingDebtDetails.fromJson(Map<String, dynamic> json) {
    return OutstandingDebtDetails(
      youOweFriend: json['youOweFriend']?.toString() ?? '0.00',
      friendOwesYou: json['friendOwesYou']?.toString() ?? '0.00',
    );
  }
}

class RemovalCheckModel {
  final bool hasOutstandingDebt;
  final bool requiresExplicitDebtConfirmation;
  final OutstandingDebtDetails? outstanding;
  final String? warningMessage;

  const RemovalCheckModel({
    required this.hasOutstandingDebt,
    required this.requiresExplicitDebtConfirmation,
    this.outstanding,
    this.warningMessage,
  });

  factory RemovalCheckModel.fromJson(Map<String, dynamic> json) {
    return RemovalCheckModel(
      hasOutstandingDebt: json['hasOutstandingDebt'] as bool? ?? false,
      requiresExplicitDebtConfirmation:
          json['requiresExplicitDebtConfirmation'] as bool? ?? false,
      outstanding: json['outstanding'] != null
          ? OutstandingDebtDetails.fromJson(
              json['outstanding'] as Map<String, dynamic>,
            )
          : null,
      warningMessage: json['warning'] is Map
          ? json['warning']['message']?.toString()
          : null,
    );
  }
}
