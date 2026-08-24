import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pingpay_mobile/features/notifications/models/app_notification_model.dart';
import 'package:pingpay_mobile/features/notifications/providers/notification_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unit: Notification Center 30-Day Auto Purge & Read Filter', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Filters out read notifications and notifications older than 30 days', () async {
      final container = ProviderContainer();
      final now = DateTime.now();

      final notifNewUnread = AppNotificationItem(
        id: 'notif-1',
        title: 'New Unread',
        body: 'Body 1',
        type: NotificationType.systemGeneral,
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: false,
      );

      final notifNewRead = AppNotificationItem(
        id: 'notif-2',
        title: 'New Read',
        body: 'Body 2',
        type: NotificationType.paymentReceived,
        createdAt: now.subtract(const Duration(hours: 5)),
        isRead: true,
      );

      final notifOldUnread = AppNotificationItem(
        id: 'notif-3',
        title: 'Old Unread > 30 days',
        body: 'Body 3',
        type: NotificationType.friendAdded,
        createdAt: now.subtract(const Duration(days: 35)),
        isRead: false,
      );

      // Set push notifications in state
      final notifier = container.read(notificationNotifierProvider.notifier);
      notifier.state = notifier.state.copyWith(
        pushNotifications: [notifNewUnread, notifNewRead, notifOldUnread],
      );

      final filtered = container.read(allNotificationsProvider);

      // Only 'notif-1' should be present!
      expect(filtered.length, 1);
      expect(filtered.first.id, 'notif-1');
    });

    test('markAsRead immediately hides the notification from feed', () async {
      final container = ProviderContainer();
      final now = DateTime.now();

      final notif = AppNotificationItem(
        id: 'notif-live',
        title: 'Live Alert',
        body: 'Body',
        type: NotificationType.systemGeneral,
        createdAt: now.subtract(const Duration(minutes: 10)),
        isRead: false,
      );

      final notifier = container.read(notificationNotifierProvider.notifier);
      notifier.state = notifier.state.copyWith(
        pushNotifications: [notif],
      );

      expect(container.read(allNotificationsProvider).length, 1);

      // Mark as read
      notifier.markAsRead('notif-live');

      // Should now be excluded ("ถ้าอ่านแล้วไม่ให้ขึ้นอีก")
      expect(container.read(allNotificationsProvider).length, 0);
      expect(container.read(totalUnreadNotificationCountProvider), 0);
    });

    test('markAllAsRead clears all notifications from feed', () async {
      final container = ProviderContainer();
      final now = DateTime.now();

      final notif1 = AppNotificationItem(
        id: 'notif-a',
        title: 'Alert A',
        body: 'Body A',
        type: NotificationType.systemGeneral,
        createdAt: now.subtract(const Duration(minutes: 10)),
        isRead: false,
      );
      final notif2 = AppNotificationItem(
        id: 'notif-b',
        title: 'Alert B',
        body: 'Body B',
        type: NotificationType.paymentReceived,
        createdAt: now.subtract(const Duration(minutes: 5)),
        isRead: false,
      );

      final notifier = container.read(notificationNotifierProvider.notifier);
      notifier.state = notifier.state.copyWith(
        pushNotifications: [notif1, notif2],
      );

      expect(container.read(allNotificationsProvider).length, 2);

      notifier.markAllAsRead();

      expect(container.read(allNotificationsProvider).length, 0);
      expect(container.read(totalUnreadNotificationCountProvider), 0);
    });

    test('SharedPreferences auto-purges read records older than 30 days', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const fortyDaysMs = 40 * 24 * 60 * 60 * 1000;
      const twoDaysMs = 2 * 24 * 60 * 60 * 1000;

      final initialPrefsMap = {
        'old-read-id': nowMs - fortyDaysMs,
        'recent-read-id': nowMs - twoDaysMs,
      };

      SharedPreferences.setMockInitialValues({
        'read_notifications_map_v1': jsonEncode(initialPrefsMap),
      });

      final container = ProviderContainer();
      // Trigger lazy notifier initialization
      container.read(notificationNotifierProvider);

      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(notificationNotifierProvider);
      expect(state.readNotificationIds.contains('recent-read-id'), true);
      expect(state.readNotificationIds.contains('old-read-id'), false);
    });
  });
}
