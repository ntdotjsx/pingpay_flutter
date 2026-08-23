import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import '../utils/app_toast.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../app/router/app_router.dart';

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
  String? _fcmToken;

  NotificationService(this._client);

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request notification permissions
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

      debugPrint('FCM User permission status: ${settings.authorizationStatus}');

      // Get initial FCM token
      _fcmToken = await messaging.getToken();
      debugPrint('FCM Device Token: $_fcmToken');

      if (_fcmToken != null) {
        await registerTokenWithBackend(_fcmToken!);
      }

      // Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        registerTokenWithBackend(newToken);
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a foreground message: ${message.notification?.title} - ${message.notification?.body}');
        final title = message.notification?.title ?? 'การแจ้งเตือนใหม่';
        final body = message.notification?.body ?? '';
        
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
