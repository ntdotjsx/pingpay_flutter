import 'dart:io';
import 'package:flutter/foundation.dart';

enum Environment { dev, staging, prod }

class AppConfig {
  AppConfig._();

  static Environment currentEnvironment = Environment.prod;

  // Resolves suitable localhost/LAN base URL according to the current platform
  static String get baseUrl {
    switch (currentEnvironment) {
      case Environment.prod:
        return 'https://pingpay-api.fly.dev';
      case Environment.staging:
        return 'https://staging-api.pingpay.app';
      case Environment.dev:
        if (kIsWeb) {
          return 'http://localhost:3000';
        }
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:3000';
        }
        if (Platform.isIOS ||
            Platform.isMacOS ||
            Platform.isWindows ||
            Platform.isLinux) {
          return 'http://localhost:3000';
        }
        return 'http://localhost:3000';
    }
  }

  static String get realtimeUrl {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: wsScheme, path: '/realtime').toString();
  }

  static const String appName = 'PingPay';
  static const Duration connectTimeout = Duration(seconds: 45);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
