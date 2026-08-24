import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingpay_mobile/core/theme/theme.dart';
import 'package:pingpay_mobile/core/widgets/app_button.dart';
import 'package:pingpay_mobile/features/auth/presentation/login_screen.dart';
import 'package:pingpay_mobile/features/auth/providers/auth_provider.dart';

void main() {
  testWidgets('AppButton renders text and triggers callback', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: LightTheme.theme,
        home: Scaffold(
          body: AppButton(text: 'ดำเนินการต่อ', onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.text('ดำเนินการต่อ'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isTrue);
  });

  testWidgets('AppButton displays loading spinner when isLoading is true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LightTheme.theme,
        home: const Scaffold(
          body: AppButton(text: 'ดำเนินการต่อ', isLoading: true),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LoginScreen renders official Google Login button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => AuthNotifierMock(
              const AuthState(status: AuthStatus.unauthenticated),
            ),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('ยินดีต้อนรับสู่ PingPay'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
  });
}

class AuthNotifierMock extends StateNotifier<AuthState>
    implements AuthNotifier {
  AuthNotifierMock(super.state);

  @override
  void forceUnauthenticated([String? reason]) {}

  @override
  Future<void> checkSession() async {}

  @override
  Future<void> authenticateWithGoogleTokens({
    String? idToken,
    String? accessToken,
    String? mockGoogleId,
    String? mockEmail,
    String? mockDisplayName,
  }) async {}

  @override
  Future<void> acceptPdpa() async {}

  @override
  Future<void> setupPin(String pin) async {}

  @override
  Future<void> changePin({String? currentPin, required String newPin}) async {}

  @override
  Future<void> updateShippingAddress({
    required String recipientName,
    required String phone,
    required String address,
  }) async {}

  @override
  Future<void> refreshUser() async {}

  @override
  void lockApp() {}

  @override
  void unlockApp() {}

  @override
  Future<bool> verifyPin(String pin) async => true;

  @override
  Future<void> completeProfile(
    String fullName, {
    String? displayName,
    String? phone,
    String? address,
    String? promptPayId,
    String? bankAccountNumber,
  }) async {}

  @override
  Future<void> logout() async {}
}
