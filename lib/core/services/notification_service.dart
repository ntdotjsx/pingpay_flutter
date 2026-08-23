import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import '../utils/app_toast.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../app/router/app_router.dart';

const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'การแจ้งเตือนสำคัญ',
  description: 'ใช้สำหรับแจ้งเตือนบิลใหม่ การชำระเงิน และยอดค้างชำระ',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background FCM message: ${message.messageId}');
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final client = ref.watch(dioClientProvider);
  return NotificationService(client);
});

class NotificationService {
  final DioClient _client;
  static String? currentFcmToken;
  String? _fcmToken;

  NotificationService(this._client);

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 1. Initialize Flutter Local Notifications for heads-up alerts
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      // Create Android Notification Channel
      if (Platform.isAndroid) {
        final androidImplementation = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(highImportanceChannel);
          await androidImplementation.requestNotificationsPermission();
        }
      }

      // 2. Request notification permissions from Firebase
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // iOS foreground presentation
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('FCM User permission status: ${settings.authorizationStatus}');

      // 3. Get initial FCM token
      _fcmToken = await messaging.getToken();
      currentFcmToken = _fcmToken;
      debugPrint('FCM Device Token: $_fcmToken');

      if (_fcmToken != null) {
        await registerTokenWithBackend(_fcmToken!);
      }

      // Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        currentFcmToken = newToken;
        registerTokenWithBackend(newToken);
      });

      // 4. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a foreground message: ${message.notification?.title} - ${message.notification?.body}');
        final notification = message.notification;
        final title = notification?.title ?? message.data['title'] ?? 'การแจ้งเตือนใหม่';
        final body = notification?.body ?? message.data['body'] ?? '';

        // Display system heads-up notification banner
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              highImportanceChannel.id,
              highImportanceChannel.name,
              channelDescription: highImportanceChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );

        // Also display modern in-app toast
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          AppToast.info(context, body, title: title);
        }
      });

      // Message opened app from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('User opened app from notification: ${message.data}');
      });
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  Future<void> registerTokenWithBackend(String token) async {
    try {
      await _client.post(
        '/api/v1/notifications/device-token',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      debugPrint('Successfully registered FCM token with backend.');
    } catch (e) {
      debugPrint('Failed to register FCM token with backend: $e');
    }
  }
}
