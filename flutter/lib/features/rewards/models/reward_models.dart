class RewardItemModel {
  final String id;
  final String title;
  final String? description;
  final int pointsCost;
  final String category;
  final String? imageUrl;
  final int inStock;
  final bool isActive;

  const RewardItemModel({
    required this.id,
    required this.title,
    this.description,
    required this.pointsCost,
    this.category = 'physical',
    this.imageUrl,
    this.inStock = 100,
    this.isActive = true,
  });

  factory RewardItemModel.fromJson(Map<String, dynamic> json) {
    return RewardItemModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      pointsCost: json['pointsCost'] is int
          ? json['pointsCost'] as int
          : (int.tryParse(json['pointsCost']?.toString() ?? '0') ?? 0),
      category: json['category'] as String? ?? 'physical',
      imageUrl: json['imageUrl'] as String?,
      inStock: json['inStock'] is int
          ? json['inStock'] as int
          : (int.tryParse(json['inStock']?.toString() ?? '0') ?? 0),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'pointsCost': pointsCost,
    'category': category,
    'imageUrl': imageUrl,
    'inStock': inStock,
    'isActive': isActive,
  };
}

class UserTierLevel {
  final int level;
  final String title;
  final String badge;
  final int minAmount;
  final int maxAmount;
  final int rewardPointsEarned;
  final double nextTierProgress;

  const UserTierLevel({
    required this.level,
    required this.title,
    required this.badge,
    required this.minAmount,
    required this.maxAmount,
    required this.rewardPointsEarned,
    this.nextTierProgress = 0.0,
  });

  static UserTierLevel calculateFromPoints(int points) {
    if (points >= 1000) {
      return const UserTierLevel(
        level: 5,
        title: 'Diamond Member',
        badge: '💎',
        minAmount: 5000,
        maxAmount: 99999,
        rewardPointsEarned: 300,
        nextTierProgress: 1.0,
      );
    } else if (points >= 500) {
      return UserTierLevel(
        level: 4,
        title: 'Platinum Member',
        badge: '👑',
        minAmount: 2000,
        maxAmount: 5000,
        rewardPointsEarned: 150,
        nextTierProgress: ((points - 500) / 500).clamp(0.0, 1.0),
      );
    } else if (points >= 200) {
      return UserTierLevel(
        level: 3,
        title: 'Gold Member',
        badge: '🥇',
        minAmount: 500,
        maxAmount: 2000,
        rewardPointsEarned: 60,
        nextTierProgress: ((points - 200) / 300).clamp(0.0, 1.0),
      );
    } else if (points >= 50) {
      return UserTierLevel(
        level: 2,
        title: 'Silver Member',
        badge: '🥈',
        minAmount: 100,
        maxAmount: 500,
        rewardPointsEarned: 25,
        nextTierProgress: ((points - 50) / 150).clamp(0.0, 1.0),
      );
    } else {
      return UserTierLevel(
        level: 1,
        title: 'Bronze Member',
        badge: '🥉',
        minAmount: 0,
        maxAmount: 100,
        rewardPointsEarned: 10,
        nextTierProgress: (points / 50).clamp(0.0, 1.0),
      );
    }
  }
}

class UserPointsInfoModel {
  final int rewardPoints;
  final String? shippingAddress;
  final String? shippingPhone;
  final String? shippingRecipientName;
  final UserTierLevel tier;

  UserPointsInfoModel({
    this.rewardPoints = 27,
    this.shippingAddress,
    this.shippingPhone,
    this.shippingRecipientName,
    UserTierLevel? tier,
  }) : tier = tier ?? UserTierLevel.calculateFromPoints(rewardPoints);

  factory UserPointsInfoModel.fromJson(Map<String, dynamic> json) {
    final pts = json['rewardPoints'] is int
        ? json['rewardPoints'] as int
        : (int.tryParse(json['rewardPoints']?.toString() ?? '27') ?? 27);

    return UserPointsInfoModel(
      rewardPoints: pts,
      shippingAddress: json['shippingAddress'] as String?,
      shippingPhone: json['shippingPhone'] as String?,
      shippingRecipientName: json['shippingRecipientName'] as String?,
      tier: UserTierLevel.calculateFromPoints(pts),
    );
  }
}

class RewardRedemptionModel {
  final String id;
  final int pointsSpent;
  final String status;
  final String recipientName;
  final String phoneNumber;
  final String shippingAddress;
  final String? trackingNumber;
  final DateTime createdAt;
  final RewardItemModel rewardItem;

  const RewardRedemptionModel({
    required this.id,
    required this.pointsSpent,
    required this.status,
    required this.recipientName,
    required this.phoneNumber,
    required this.shippingAddress,
    this.trackingNumber,
    required this.createdAt,
    required this.rewardItem,
  });

  factory RewardRedemptionModel.fromJson(Map<String, dynamic> json) {
    return RewardRedemptionModel(
      id: json['id'] as String? ?? '',
      pointsSpent: json['pointsSpent'] is int
          ? json['pointsSpent'] as int
          : (int.tryParse(json['pointsSpent']?.toString() ?? '0') ?? 0),
      status: json['status'] as String? ?? 'pending_delivery',
      recipientName: json['recipientName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      shippingAddress: json['shippingAddress'] as String? ?? '',
      trackingNumber: json['trackingNumber'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      rewardItem: json['rewardItem'] != null
          ? RewardItemModel.fromJson(json['rewardItem'] as Map<String, dynamic>)
          : const RewardItemModel(
              id: '',
              title: 'ของรางวัล',
              pointsCost: 0,
            ),
    );
  }
}
