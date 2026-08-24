import 'package:flutter/material.dart';

enum NotificationCategory {
  all,
  debts,
  payments,
  friendsAndRewards,
  system,
}

enum NotificationType {
  debtRequest,
  paymentReceived,
  paymentConfirmed,
  slipVerified,
  friendRequest,
  friendAdded,
  rewardPointsEarned,
  rewardShipped,
  systemSecurity,
  systemGeneral,
}

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final double? amount;
  final String? relatedId;
  final String? avatarUrl;
  final Map<String, dynamic>? metadata;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.amount,
    this.relatedId,
    this.avatarUrl,
    this.metadata,
  });

  NotificationCategory get category {
    switch (type) {
      case NotificationType.debtRequest:
        return NotificationCategory.debts;
      case NotificationType.paymentReceived:
      case NotificationType.paymentConfirmed:
      case NotificationType.slipVerified:
        return NotificationCategory.payments;
      case NotificationType.friendRequest:
      case NotificationType.friendAdded:
      case NotificationType.rewardPointsEarned:
      case NotificationType.rewardShipped:
        return NotificationCategory.friendsAndRewards;
      case NotificationType.systemSecurity:
      case NotificationType.systemGeneral:
        return NotificationCategory.system;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.debtRequest:
        return Icons.receipt_long_rounded;
      case NotificationType.paymentReceived:
        return Icons.account_balance_wallet_rounded;
      case NotificationType.paymentConfirmed:
        return Icons.check_circle_rounded;
      case NotificationType.slipVerified:
        return Icons.verified_user_rounded;
      case NotificationType.friendRequest:
      case NotificationType.friendAdded:
        return Icons.person_add_rounded;
      case NotificationType.rewardPointsEarned:
        return Icons.monetization_on_rounded;
      case NotificationType.rewardShipped:
        return Icons.local_shipping_rounded;
      case NotificationType.systemSecurity:
        return Icons.shield_rounded;
      case NotificationType.systemGeneral:
        return Icons.info_outline_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.debtRequest:
        return const Color(0xFFFF5000);
      case NotificationType.paymentReceived:
      case NotificationType.paymentConfirmed:
        return const Color(0xFF34C759);
      case NotificationType.slipVerified:
        return const Color(0xFF007AFF);
      case NotificationType.friendRequest:
      case NotificationType.friendAdded:
        return const Color(0xFF5856D6);
      case NotificationType.rewardPointsEarned:
        return const Color(0xFFFF9500);
      case NotificationType.rewardShipped:
        return const Color(0xFF30B0C7);
      case NotificationType.systemSecurity:
        return const Color(0xFFFF2D55);
      case NotificationType.systemGeneral:
        return const Color(0xFF8E8E93);
    }
  }

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    double? amount,
    String? relatedId,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      amount: amount ?? this.amount,
      relatedId: relatedId ?? this.relatedId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
    );
  }
}
