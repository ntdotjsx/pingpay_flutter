import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pingpay_mobile/main.dart';
import 'package:pingpay_mobile/features/auth/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PingPayApp initializes and renders successfully', (
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
        child: const PingPayApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('ยินดีต้อนรับสู่ PingPay'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย LINE'), findsOneWidget);
  });
}

class AuthNotifierMock extends StateNotifier<AuthState>
    implements AuthNotifier {
  AuthNotifierMock(super.state);

  @override
  void forceUnauthenticated() {}

  @override
  Future<void> checkSession() async {}

  @override
  Future<void> authenticateWithLineTokens({
    String? idToken,
    String? accessToken,
    String? mockLineUserId,
    String? mockDisplayName,
  }) async {}

  @override
  Future<void> acceptPdpa() async {}

  @override
  Future<void> setupPin(String pin) async {}

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
