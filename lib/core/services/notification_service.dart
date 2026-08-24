import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  bool _didScheduleTokenRetry = false;
  static final StreamController<RemoteMessage> _pushStreamController = StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get onPushMessage => _pushStreamController.stream;

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
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
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
      } else if (Platform.isIOS) {
        final iosImplementation = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (iosImplementation != null) {
          await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      }

      // 2. Request notification permissions from Firebase
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
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
      _fcmToken = await ensureFcmToken();
      currentFcmToken = _fcmToken;
      debugPrint('FCM Device Token: $_fcmToken');

      if (_fcmToken != null) {
        await registerTokenWithBackend(_fcmToken!);
      } else {
        _scheduleTokenRetry();
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
        _pushStreamController.add(message);
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
        _pushStreamController.add(message);
      });
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  static Future<String?> ensureFcmToken() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);

    if (!kIsWeb && Platform.isIOS) {
      final apnsToken = await _waitForApnsToken(messaging, attempts: 6);
      if (apnsToken != null) {
        debugPrint('APNs token is available for FCM registration.');
      } else {
        debugPrint('APNs token not returned immediately. Attempting direct FCM token retrieval.');
      }
    }

    try {
      final token = await messaging.getToken();
      currentFcmToken = token;
      return token;
    } catch (e) {
      debugPrint('Could not retrieve FCM token: $e');
      return null;
    }
  }

  static Future<NotificationSettings?> requestNotificationPermission() async {
    try {
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

      if (Platform.isIOS) {
        final iosPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final token = await ensureFcmToken();
      if (token != null) {
        currentFcmToken = token;
      }
      return settings;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return null;
    }
  }

  void _scheduleTokenRetry() {
    if (_didScheduleTokenRetry) return;
    _didScheduleTokenRetry = true;

    Future<void>.delayed(const Duration(seconds: 8), () async {
      final token = await ensureFcmToken();
      if (token == null) {
        _didScheduleTokenRetry = false;
        debugPrint('FCM token retry did not produce a token yet.');
        return;
      }

      _fcmToken = token;
      await registerTokenWithBackend(token);
    });
  }

  static Future<String?> _waitForApnsToken(
    FirebaseMessaging messaging, {
    int attempts = 15,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        final token = await messaging.getAPNSToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('[iOS APNs] APNs token retrieved successfully on attempt ${attempt + 1}: $token');
          return token;
        }
      } catch (e) {
        debugPrint('[iOS APNs] APNs token attempt ${attempt + 1} failed: $e');
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return null;
  }

  static Future<Map<String, String>> getDeviceMetadata() async {
    String deviceName = 'Mobile Device';
    String deviceModel = 'Generic Device';
    String deviceBrand = 'Android';
    String osVersion = 'Android';
    String appVersion = '1.0.0';

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceBrand = 'Web';
        deviceModel = webInfo.browserName.name;
        deviceName = '${webInfo.browserName.name} Browser';
        osVersion = webInfo.userAgent ?? 'Web';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand.isNotEmpty
            ? androidInfo.brand
            : (androidInfo.manufacturer.isNotEmpty ? androidInfo.manufacturer : 'Android');
        deviceBrand = brand;
        deviceModel = androidInfo.model.isNotEmpty ? androidInfo.model : 'Android Device';

        final mfg = androidInfo.manufacturer.isNotEmpty ? androidInfo.manufacturer : brand;
        deviceName = '$mfg ${androidInfo.model}'.trim();
        if (deviceName.isEmpty) deviceName = '$brand $deviceModel'.trim();
        osVersion = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceBrand = 'Apple';
        deviceModel = iosInfo.utsname.machine.isNotEmpty ? iosInfo.utsname.machine : iosInfo.model;
        deviceName = iosInfo.name.isNotEmpty ? iosInfo.name : 'iPhone';
        osVersion = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        deviceBrand = 'Microsoft';
        deviceModel = 'Windows PC';
        deviceName = winInfo.computerName.isNotEmpty ? winInfo.computerName : 'Windows PC';
        osVersion = 'Windows ${winInfo.displayVersion}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceBrand = 'Apple';
        deviceModel = macInfo.model;
        deviceName = macInfo.computerName;
        osVersion = 'macOS ${macInfo.osRelease}';
      }
    } catch (e) {
      debugPrint('[DeviceInfo] Error getting native device info: $e');
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      debugPrint('[DeviceInfo] Error getting package info: $e');
    }

    return {
      'deviceName': deviceName,
      'deviceModel': deviceModel,
      'deviceBrand': deviceBrand,
      'osVersion': osVersion,
      'appVersion': appVersion,
    };
  }

  Future<void> registerTokenWithBackend(String token) async {
    try {
      final metadata = await getDeviceMetadata();
      await _client.post(
        '/api/v1/notifications/device-token',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          ...metadata,
        },
      );
      debugPrint('Successfully registered FCM token with backend (${metadata['deviceName']}).');
    } catch (e) {
      debugPrint('Failed to register FCM token with backend: $e');
    }
  }
}
