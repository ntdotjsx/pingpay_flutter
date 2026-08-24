import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../payments/models/payment_models.dart';
import '../../payments/providers/payment_providers.dart';
import '../models/app_notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationState {
  final List<AppNotificationItem> backendNotifications;
  final List<AppNotificationItem> pushNotifications;
  final Set<String> readNotificationIds;
  final NotificationCategory selectedCategory;
  final bool isLoading;

  const NotificationState({
    this.backendNotifications = const [],
    this.pushNotifications = const [],
    this.readNotificationIds = const {},
    this.selectedCategory = NotificationCategory.all,
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<AppNotificationItem>? backendNotifications,
    List<AppNotificationItem>? pushNotifications,
    Set<String>? readNotificationIds,
    NotificationCategory? selectedCategory,
    bool? isLoading,
  }) {
    return NotificationState(
      backendNotifications: backendNotifications ?? this.backendNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      readNotificationIds: readNotificationIds ?? this.readNotificationIds,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final Ref _ref;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  StreamSubscription<RemoteMessage>? _pushSubscription;
  static const String _kReadNotificationsPrefKey = 'read_notifications_map_v1';

  NotificationNotifier(this._ref) : super(const NotificationState()) {
    _loadPersistedReadIds();
    _listenToRealtime();
    _listenToPushNotifications();
    _listenToAuthAndFetch();
  }

  /// Loads read IDs and automatically purges any records older than 30 days
  Future<void> _loadPersistedReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kReadNotificationsPrefKey);
      if (raw == null || raw.isEmpty) return;

      final Map<String, dynamic> decoded = jsonDecode(raw);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

      final validReadIds = <String>{};
      final prunedMap = <String, int>{};

      decoded.forEach((key, val) {
        final timestamp = (val is num) ? val.toInt() : int.tryParse(val.toString()) ?? 0;
        // Keep if younger than 30 days
        if (nowMs - timestamp < thirtyDaysMs) {
          validReadIds.add(key);
          prunedMap[key] = timestamp;
        }
      });

      state = state.copyWith(readNotificationIds: validReadIds);

      // Save pruned map back to storage
      await prefs.setString(_kReadNotificationsPrefKey, jsonEncode(prunedMap));
    } catch (e) {
      debugPrint('Error loading persisted read notifications: $e');
    }
  }

  Future<void> _persistReadIds(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kReadNotificationsPrefKey);
      final Map<String, dynamic> map = raw != null && raw.isNotEmpty ? jsonDecode(raw) : {};

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

      for (final id in ids) {
        map[id] = nowMs;
      }

      // Prune old entries
      map.removeWhere((_, val) {
        final ts = (val is num) ? val.toInt() : int.tryParse(val.toString()) ?? 0;
        return (nowMs - ts) >= thirtyDaysMs;
      });

      await prefs.setString(_kReadNotificationsPrefKey, jsonEncode(map));
    } catch (e) {
      debugPrint('Error persisting read notifications: $e');
    }
  }

  void _listenToAuthAndFetch() {
    _ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && next.user?.id != null) {
        fetchBackendNotifications();
      }
    }, fireImmediately: true);
  }

  Future<void> fetchBackendNotifications() async {
    final user = _ref.read(authStateProvider).user;
    if (user == null || user.id.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(notificationRepositoryProvider);
      final items = await repo.getUserNotifications(user.id);
      state = state.copyWith(
        backendNotifications: items,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _listenToPushNotifications() {
    _pushSubscription = NotificationService.onPushMessage.listen((message) {
      _handleIncomingPushMessage(message);
    });
  }

  void _handleIncomingPushMessage(RemoteMessage message) {
    final now = DateTime.now();
    final data = message.data;
    final notification = message.notification;

    final id = message.messageId ?? 'push-${now.millisecondsSinceEpoch}';
    final title = notification?.title ?? data['title'] ?? 'การแจ้งเตือนใหม่';
    final body = notification?.body ?? data['body'] ?? '';
    final eventType = data['type'] ?? data['eventType'] ?? '';
    final amount = (data['amount'] is num)
        ? (data['amount'] as num).toDouble()
        : double.tryParse(data['amount']?.toString() ?? '');
    final imageUrl = notification?.android?.imageUrl ??
        notification?.apple?.imageUrl ??
        data['imageUrl'] ??
        data['image'] ??
        data['bannerUrl'];
    final avatarUrl = data['avatarUrl'] ?? data['avatar'] ?? data['senderAvatar'] ?? data['iconUrl'];

    NotificationType type = NotificationType.systemGeneral;
    if (eventType.contains('debt') || eventType.contains('bill') || eventType == 'BILL_CREATED') {
      type = NotificationType.debtRequest;
    } else if (eventType.contains('payment') || eventType == 'PAYMENT_PENDING_CONFIRMATION') {
      type = NotificationType.paymentReceived;
    } else if (eventType.contains('friend')) {
      type = NotificationType.friendAdded;
    } else if (eventType.contains('reward')) {
      type = NotificationType.rewardPointsEarned;
    }

    final item = AppNotificationItem(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAt: now,
      isRead: false,
      amount: amount,
      relatedId: data['billId'] ?? data['paymentId'] ?? data['friendshipId'],
      avatarUrl: avatarUrl?.toString(),
      imageUrl: imageUrl?.toString(),
      metadata: data,
    );

    state = state.copyWith(
      pushNotifications: [item, ...state.pushNotifications],
    );
  }

  void _listenToRealtime() {
    try {
      final realtimeService = _ref.read(realtimeServiceProvider);
      _realtimeSubscription = realtimeService.events.listen((event) {
        _handleIncomingRealtimeEvent(event);
      });
    } catch (_) {}
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
        pushNotifications: [item, ...state.pushNotifications],
      );
    }
  }

  void setCategory(NotificationCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  void markAsRead(String id) {
    final updated = Set<String>.from(state.readNotificationIds)..add(id);
    state = state.copyWith(readNotificationIds: updated);
    _persistReadIds({id});
  }

  void markAllAsRead() {
    final allIds = <String>{};
    for (final item in state.backendNotifications) {
      allIds.add(item.id);
    }
    for (final item in state.pushNotifications) {
      allIds.add(item.id);
    }
    final debts = _ref.read(pendingDebtRequestsProvider);
    for (final d in debts) {
      allIds.add('debt-${d.id}');
    }
    final updated = Set<String>.from(state.readNotificationIds)..addAll(allIds);
    state = state.copyWith(readNotificationIds: updated);
    _persistReadIds(allIds);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _pushSubscription?.cancel();
    super.dispose();
  }
}

final notificationNotifierProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});

/// Aggregated notifications combining:
/// 1. Real push notifications (FCM & Realtime Events)
/// 2. Real backend Outbox notifications (from /api/v1/notifications/user/:id)
/// 3. Live pending Debt Acknowledgement Requests (from userDebtsProvider)
///
/// Filters applied:
/// - "ถ้าอ่านแล้วไม่ให้ขึ้นอีก": Read notifications are filtered out immediately.
/// - "ล้างเองทุก 30 วัน": Notifications older than 30 days are automatically purged.
final allNotificationsProvider = Provider<List<AppNotificationItem>>((ref) {
  final notifState = ref.watch(notificationNotifierProvider);
  final pendingDebts = ref.watch(pendingDebtRequestsProvider);

  final Map<String, AppNotificationItem> merged = {};
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  // 1. Live Pending Debts (highest priority) - only if not read/acknowledged and < 30 days
  for (final debt in pendingDebts) {
    final id = 'debt-${debt.id}';
    final isRead = notifState.readNotificationIds.contains(id);

    if (!isRead && debt.debtStartDate.isAfter(thirtyDaysAgo)) {
      merged[id] = AppNotificationItem(
        id: id,
        title: 'มีคำขอรับสภาพหนี้ใหม่ 🧾',
        body: '${debt.creditor.displayName} เพิ่มคุณในบิล "${debt.billTitle}" ยอดค้าง ฿${debt.outstandingAmount.toStringAsFixed(2)}',
        type: NotificationType.debtRequest,
        createdAt: debt.debtStartDate,
        isRead: false,
        amount: debt.outstandingAmount,
        relatedId: debt.id,
        metadata: {'debtItem': debt},
      );
    }
  }

  // 2. Real Push Notifications (FCM / Realtime) - only if unread and < 30 days
  for (final item in notifState.pushNotifications) {
    final isRead = item.isRead || notifState.readNotificationIds.contains(item.id);
    if (!isRead && item.createdAt.isAfter(thirtyDaysAgo)) {
      merged[item.id] = item.copyWith(isRead: false);
    }
  }

  // 3. Real Backend Outbox History - only if unread and < 30 days
  for (final item in notifState.backendNotifications) {
    if (!merged.containsKey(item.id)) {
      final isRead = item.isRead || notifState.readNotificationIds.contains(item.id);
      if (!isRead && item.createdAt.isAfter(thirtyDaysAgo)) {
        merged[item.id] = item.copyWith(isRead: false);
      }
    }
  }

  final list = merged.values.toList();
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  if (notifState.selectedCategory == NotificationCategory.all) {
    return list;
  }

  return list.where((n) => n.category == notifState.selectedCategory).toList();
});

/// Total Unread Notifications Count for Bell Badge
final totalUnreadNotificationCountProvider = Provider<int>((ref) {
  final allNotifs = ref.watch(allNotificationsProvider);
  return allNotifs.length;
});
