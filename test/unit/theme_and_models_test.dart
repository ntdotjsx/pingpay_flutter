import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pingpay_mobile/core/theme/theme.dart';
import 'package:pingpay_mobile/core/utils/input_validators.dart';
import 'package:pingpay_mobile/features/auth/models/auth_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unit: ThemeModeNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial theme mode is system', () {
      final notifier = ThemeModeNotifier();
      expect(notifier.state, ThemeMode.system);
    });

    test('Can change and persist light theme', () async {
      final notifier = ThemeModeNotifier();
      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_theme_mode'), 'light');
    });

    test('Can change and persist dark theme', () async {
      final notifier = ThemeModeNotifier();
      await notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_theme_mode'), 'dark');
    });
  });

  group('Unit: Auth Models Serialization', () {
    test('UserModel.fromJson parses user and onboarding status correctly', () {
      final json = {
        'userId': 'user-123',
        'userCode': 'USR-ABCDEF',
        'displayName': 'Nut Thanapon',
        'avatarUrl': 'https://example.com/avatar.png',
        'role': 'user',
        'onboardingState': 'PDPA_REQUIRED',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'user-123');
      expect(user.displayName, 'Nut Thanapon');
      expect(user.onboardingState, OnboardingState.pdpaRequired);
    });

    test('UserModel.fromJson parses payment channel and name fields correctly', () {
      final json = {
        'userId': 'user-123',
        'userCode': 'USR-ABCDEF',
        'displayName': 'Nut Thanapon',
        'fullName': 'Thanapon Phorarmat',
        'firstName': 'Thanapon',
        'lastName': 'Phorarmat',
        'promptPayId': '0826419844',
        'bankAccountNumber': '1234567890',
        'bankName': 'ธนาคารกสิกรไทย (Kasikornbank)',
        'bankCode': 'KBANK',
        'truemoneyPhone': '0826419844',
      };

      final user = UserModel.fromJson(json);
      expect(user.fullName, 'Thanapon Phorarmat');
      expect(user.firstName, 'Thanapon');
      expect(user.lastName, 'Phorarmat');
      expect(user.bankCode, 'KBANK');
      expect(user.truemoneyPhone, '0826419844');
    });

    test('PdpaConsentModel.fromJson parses policy version and acceptance', () {
      final json = {
        'policyVersion': 'v1.0.0',
        'hasAccepted': true,
        'lastAcceptedAt': '2026-08-18T10:00:00Z',
      };

      final model = PdpaConsentModel.fromJson(json);
      expect(model.policyVersion, 'v1.0.0');
      expect(model.hasAccepted, true);
    });
  });

  group('Unit: InputValidators.validateRealName', () {
    test('rejects empty and whitespace string', () {
      expect(InputValidators.validateRealName(''), isNotNull);
      expect(InputValidators.validateRealName('   '), isNotNull);
    });

    test('rejects single word name without last name', () {
      expect(InputValidators.validateRealName('ธนพล'), contains('ทั้งชื่อและนามสกุล'));
      expect(InputValidators.validateRealName('Thanapon'), contains('ทั้งชื่อและนามสกุล'));
    });

    test('rejects names with numbers or special symbols', () {
      expect(InputValidators.validateRealName('ธนพล123 พรหมมาศ'), contains('ตัวอักษรเท่านั้น'));
      expect(InputValidators.validateRealName('Thanapon P.@#'), contains('ตัวอักษรเท่านั้น'));
    });

    test('accepts valid Thai and English full names', () {
      expect(InputValidators.validateRealName('ธนพล พรหมมาศ'), isNull);
      expect(InputValidators.validateRealName('Thanapon Phorarmat'), isNull);
      expect(InputValidators.validateRealName('นาย ธนพล พรหมมาศ'), isNull);
    });
  });
}
