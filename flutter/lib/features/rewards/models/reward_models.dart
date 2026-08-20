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

class UserPointsInfoModel {
  final int rewardPoints;
  final String? shippingAddress;
  final String? shippingPhone;
  final String? shippingRecipientName;

  const UserPointsInfoModel({
    this.rewardPoints = 27,
    this.shippingAddress,
    this.shippingPhone,
    this.shippingRecipientName,
  });

  factory UserPointsInfoModel.fromJson(Map<String, dynamic> json) {
    return UserPointsInfoModel(
      rewardPoints: json['rewardPoints'] is int
          ? json['rewardPoints'] as int
          : (int.tryParse(json['rewardPoints']?.toString() ?? '27') ?? 27),
      shippingAddress: json['shippingAddress'] as String?,
      shippingPhone: json['shippingPhone'] as String?,
      shippingRecipientName: json['shippingRecipientName'] as String?,
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
