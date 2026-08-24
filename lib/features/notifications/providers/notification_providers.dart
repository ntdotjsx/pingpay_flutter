import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../payments/models/payment_models.dart';
import '../../payments/providers/payment_providers.dart';
import '../models/app_notification_model.dart';

class NotificationState {
  final List<AppNotificationItem> customNotifications;
  final Set<String> readNotificationIds;
  final NotificationCategory selectedCategory;

  const NotificationState({
    this.customNotifications = const [],
    this.readNotificationIds = const {},
    this.selectedCategory = NotificationCategory.all,
  });

  NotificationState copyWith({
    List<AppNotificationItem>? customNotifications,
    Set<String>? readNotificationIds,
    NotificationCategory? selectedCategory,
  }) {
    return NotificationState(
      customNotifications: customNotifications ?? this.customNotifications,
      readNotificationIds: readNotificationIds ?? this.readNotificationIds,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final Ref _ref;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;

  NotificationNotifier(this._ref)
      : super(NotificationState(
          customNotifications: [
            AppNotificationItem(
              id: 'sys-welcome',
              title: 'ยินดีต้อนรับสู่ PingPay 🎉',
              body: 'เริ่มต้นหารบิลค่าอาหาร ทริปเที่ยว หรือชำระหนี้กับเพื่อนได้ทันที',
              type: NotificationType.systemGeneral,
              createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
              isRead: false,
            ),
            AppNotificationItem(
              id: 'sys-security',
              title: 'เซสชันการเข้าสู่ระบบปลอดภัย 🛡️',
              body: 'บัญชีของคุณเชื่อมต่อกับเซิร์ฟเวอร์แบบ Real-time และจำกัด 1 อุปกรณ์',
              type: NotificationType.systemSecurity,
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
              isRead: false,
            ),
            AppNotificationItem(
              id: 'reward-bonus',
              title: 'แต้มสะสมเริ่มต้น +27 แต้ม 🪙',
              body: 'คุณได้รับแต้มเริ่มต้นเพื่อนำไปแลกของรางวัลในเมนู แลกคอยน์',
              type: NotificationType.rewardPointsEarned,
              createdAt: DateTime.now().subtract(const Duration(hours: 4)),
              isRead: false,
            ),
          ],
        )) {
    _listenToRealtime();
  }

  void _listenToRealtime() {
    final realtimeService = _ref.read(realtimeServiceProvider);
    _realtimeSubscription = realtimeService.events.listen((event) {
      _handleIncomingRealtimeEvent(event);
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _handleIncomingRealtimeEvent(RealtimeEvent event) {
    AppNotificationItem? item;
    final now = DateTime.now();

    switch (event.type) {
      case 'bill.created':
      case 'debt.requested':
        item = AppNotificationItem(
          id: 'rt-${event.eventId.isNotEmpty ? event.eventId : now.millisecondsSinceEpoch}',
          title: 'มีคำขอรับสภาพหนี้ใหม่ 🧾',
          body: event.data['billTitle'] != null
              ? 'เพื่อนเพิ่มคุณในบิล "${event.data['billTitle']}"'
              : 'คุณได้รับคำขอรับสภาพหนี้ใหม่จากเพื่อน',
          type: NotificationType.debtRequest,
          createdAt: now,
          amount: (event.data['amount'] is num) ? (event.data['amount'] as num).toDouble() : null,
          relatedId: event.resourceId,
          metadata: event.data,
        );
        break;

      case 'payment.submitted':
      case 'payment.received':
        item = AppNotificationItem(
          id: 'rt-${event.eventId.isNotEmpty ? event.eventId : now.millisecondsSinceEpoch}',
          title: 'เพื่อนชำระเงินแล้ว 💸',
          body: event.data['debtorName'] != null
              ? '${event.data['debtorName']} ได้ชำระเงินสำหรับบิลแล้ว'
              : 'มีการชำระเงินใหม่เข้ามาในบัญชีของคุณ',
          type: NotificationType.paymentReceived,
          createdAt: now,
          amount: (event.data['amount'] is num) ? (event.data['amount'] as num).toDouble() : null,
          relatedId: event.resourceId,
          metadata: event.data,
        );
        break;

      case 'friend.requested':
      case 'friend.accepted':
        item = AppNotificationItem(
          id: 'rt-${event.eventId.isNotEmpty ? event.eventId : now.millisecondsSinceEpoch}',
          title: 'เพื่อนและการเชื่อมต่อ 👥',
          body: event.data['friendName'] != null
              ? '${event.data['friendName']} ได้เพิ่มคุณเป็นเพื่อนแล้ว'
              : 'คุณมีกิจกรรมเพื่อนใหม่',
          type: NotificationType.friendAdded,
          createdAt: now,
          relatedId: event.resourceId,
          metadata: event.data,
        );
        break;

      case 'reward.earned':
        item = AppNotificationItem(
          id: 'rt-${event.eventId.isNotEmpty ? event.eventId : now.millisecondsSinceEpoch}',
          title: 'คุณได้รับแต้มสะสมใหม่ 🪙',
          body: event.data['points'] != null
              ? 'คุณได้รับ +${event.data['points']} แต้มจากการชำระบิลตรงเวลา'
              : 'คุณได้รับแต้มสะสมเพิ่ม',
          type: NotificationType.rewardPointsEarned,
          createdAt: now,
          metadata: event.data,
        );
        break;
    }

    if (item != null) {
      state = state.copyWith(
        customNotifications: [item, ...state.customNotifications],
      );
    }
  }

  void setCategory(NotificationCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  void markAsRead(String id) {
    final updated = Set<String>.from(state.readNotificationIds)..add(id);
    state = state.copyWith(readNotificationIds: updated);
  }

  void markAllAsRead() {
    final allIds = <String>{};
    for (final item in state.customNotifications) {
      allIds.add(item.id);
    }
    // Also include pending debts
    final debts = _ref.read(pendingDebtRequestsProvider);
    for (final d in debts) {
      allIds.add('debt-${d.id}');
    }
    state = state.copyWith(readNotificationIds: allIds);
  }
}

final notificationNotifierProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});

/// Aggregated all notifications combining:
/// 1. Pending Debt Acknowledgement Requests (live from debt provider)
/// 2. General alerts, payments, friend activities, reward bonuses, and realtime alerts
final allNotificationsProvider = Provider<List<AppNotificationItem>>((ref) {
  final notifState = ref.watch(notificationNotifierProvider);
  final pendingDebts = ref.watch(pendingDebtRequestsProvider);

  final List<AppNotificationItem> list = [];

  // Convert live pending debts into top-priority notifications
  for (final debt in pendingDebts) {
    final id = 'debt-${debt.id}';
    final isRead = notifState.readNotificationIds.contains(id);

    list.add(
      AppNotificationItem(
        id: id,
        title: 'คำร้องขอรับสภาพหนี้ใหม่ 🧾',
        body: '${debt.creditor.displayName} เพิ่มคุณในบิล "${debt.billTitle}" ยอดค้าง ฿${debt.outstandingAmount.toStringAsFixed(2)}',
        type: NotificationType.debtRequest,
        createdAt: debt.debtStartDate,
        isRead: isRead,
        amount: debt.outstandingAmount,
        relatedId: debt.id,
        metadata: {'debtItem': debt},
      ),
    );
  }

  // Add custom / realtime notifications
  for (final item in notifState.customNotifications) {
    final isRead = item.isRead || notifState.readNotificationIds.contains(item.id);
    list.add(item.copyWith(isRead: isRead));
  }

  // Sort descending by createdAt
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Filter by category if selected
  if (notifState.selectedCategory == NotificationCategory.all) {
    return list;
  }

  return list.where((n) => n.category == notifState.selectedCategory).toList();
});

/// Total Unread Notifications Count for Bell Badge
final totalUnreadNotificationCountProvider = Provider<int>((ref) {
  final notifState = ref.watch(notificationNotifierProvider);
  final pendingDebts = ref.watch(pendingDebtRequestsProvider);

  int unreadDebts = pendingDebts.where((d) => !notifState.readNotificationIds.contains('debt-${d.id}')).length;
  int unreadCustom = notifState.customNotifications.where((n) => !n.isRead && !notifState.readNotificationIds.contains(n.id)).length;

  return unreadDebts + unreadCustom;
});
