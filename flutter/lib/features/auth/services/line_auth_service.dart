import 'package:flutter/foundation.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';

class LineAuthService {
  static const String channelId = '2011160144';
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) return;

    try {
      await LineSDK.instance.setup(channelId).then((_) {
        _isInitialized = true;
      });
    } catch (_) {}
  }

  static Future<LoginResult?> login() async {
    if (kIsWeb) {
      throw Exception(
        'LINE SDK Native Login ไม่รองรับบน Web Browser โดยตรง กรุณาทดสอบบน Android / iOS หรือใช้อุปกรณ์จริง',
      );
    }

    // If not initialized, initialize first
    if (!_isInitialized) {
      await initialize();
    }

    final result = await LineSDK.instance.login(
      scopes: ['profile', 'openid', 'email'],
    );
    return result;
  }

  static Future<void> logout() async {
    try {
      await LineSDK.instance.logout();
    } catch (_) {}
  }
}
