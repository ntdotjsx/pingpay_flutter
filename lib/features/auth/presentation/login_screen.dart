import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/app_toast.dart';
import '../providers/auth_provider.dart';
import '../services/google_auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatingAnim;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatingAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    HapticFeedback.mediumImpact();
    try {
      final account = await GoogleAuthService.signIn();
      if (account != null) {
        final auth = await GoogleAuthService.getAuth(account);

        await ref
            .read(authStateProvider.notifier)
            .authenticateWithGoogleTokens(
              idToken: auth?.idToken,
              accessToken: auth?.accessToken,
              mockGoogleId: account.id,
              mockEmail: account.email,
              mockDisplayName: account.displayName,
            );
        return;
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Google Sign-In Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFFAFBFD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // 1. Mascot Illustration with Gentle Floating
              AnimatedBuilder(
                animation: _floatingAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatingAnim.value),
                    child: child,
                  );
                },
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280, maxWidth: 280),
                  child: Image.asset(
                    'assets/images/nong_ping_welcome.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Clean Minimal Branding
              Text(
                'ยินดีต้อนรับสู่ PingPay',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'จัดการบิล สแกนสลิป หารเงิน และทวงเงินเพื่อนอย่างมืออาชีพ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  height: 1.35,
                ),
              ),

              // 3. Security Warning Banner (if kicked from another device)
              if (authState.errorMessage != null && authState.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // 4. Clean High-End Google Login Button
              Container(
                width: double.infinity,
                height: 54,
                decoration: ShapeDecoration(
                  color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E6EC),
                      width: 1.0,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: authState.isLoading ? null : _handleGoogleLogin,
                    borderRadius: BorderRadius.circular(18),
                    child: Center(
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFFFF5000),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildGoogleIcon(),
                                const SizedBox(width: 12),
                                Text(
                                  'เข้าสู่ระบบด้วย Google',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Minimal Security Note
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF34C759)),
                  const SizedBox(width: 5),
                  Text(
                    'ปลอดภัยสูงสุด 1 เครื่องต่อบัญชี • มาตรฐาน PDPA',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);

    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Blue Bar
    final bluePath = Path()
      ..moveTo(center.dx, center.dy - radius * 0.2)
      ..lineTo(w, center.dy - radius * 0.2)
      ..lineTo(w, center.dy + radius * 0.2)
      ..lineTo(center.dx, center.dy + radius * 0.2)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Outer Arc - Blue
    final blueArc = Path()
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -0.5, 1.0, false)
      ..lineTo(center.dx + radius * 0.5, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius * 0.55), 0.5, -1.0, false)
      ..close();
    canvas.drawPath(blueArc, bluePaint);

    // Outer Arc - Green
    final greenArc = Path()
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 0.5, 1.1, false)
      ..lineTo(center.dx - radius * 0.3, center.dy + radius * 0.4)
      ..arcTo(Rect.fromCircle(center: center, radius: radius * 0.55), 1.6, -1.1, false)
      ..close();
    canvas.drawPath(greenArc, greenPaint);

    // Outer Arc - Yellow
    final yellowArc = Path()
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 1.6, 1.5, false)
      ..lineTo(center.dx - radius * 0.5, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius * 0.55), 3.1, -1.5, false)
      ..close();
    canvas.drawPath(yellowArc, yellowPaint);

    // Outer Arc - Red
    final redArc = Path()
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 3.1, 1.6, false)
      ..lineTo(center.dx + radius * 0.3, center.dy - radius * 0.4)
      ..arcTo(Rect.fromCircle(center: center, radius: radius * 0.55), 4.7, -1.6, false)
      ..close();
    canvas.drawPath(redArc, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
