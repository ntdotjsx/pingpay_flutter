import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../services/line_auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  Future<void> _handleLineLogin() async {
    try {
      final loginResult = await LineAuthService.login();
      if (loginResult != null) {
        final accessToken = loginResult.accessToken.value;
        final idToken = loginResult.accessToken.idTokenRaw;

        await ref
            .read(authStateProvider.notifier)
            .authenticateWithLineTokens(
              idToken: idToken,
              accessToken: accessToken,
            );
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LINE Login Error: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'ยินดีต้อนรับสู่ PingPay',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'แอปจัดการบิลและทวงเงินเพื่อนอย่างมืออาชีพ',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Official LINE SDK Login Button
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleLineLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF06C755,
                    ), // Official LINE Green
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                    elevation: 0,
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'เข้าสู่ระบบด้วย LINE',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: AppSpacing.xl),
                Text(
                  '🔒 เข้าสู่ระบบผ่าน LINE อย่างปลอดภัยโดยตรง\nข้อมูลของคุณได้รับการคุ้มครองตามมาตรฐาน PDPA',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
