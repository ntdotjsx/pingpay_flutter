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
  late final PageController _pageController;
  late final AnimationController _bounceController;
  late final Animation<double> _floatingAnimation;
  late final Animation<double> _chevronAnimation;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );

    _chevronAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bounceController.dispose();
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

  void _scrollToLogin() {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToWelcome() {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFFAFBFD),
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: [
          // ── PAGE 0: WELCOME SCREEN (MASCOT & SWIPE UP) ───────────────
          _buildWelcomePage(context, isDark),

          // ── PAGE 1: PROFESSIONAL GOOGLE LOGIN SCREEN ──────────────────
          _buildLoginPage(context, authState, isDark),
        ],
      ),
    );
  }

  // =========================================================================
  // VIEW 1: WELCOME SCREEN (MASCOT & SWIPE UP)
  // =========================================================================
  Widget _buildWelcomePage(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF1F120E),
                  AppColors.surfaceBlack,
                  AppColors.surfaceBlack,
                ]
              : [
                  const Color(0xFFFFF4EE),
                  const Color(0xFFFFFFFF),
                  const Color(0xFFF9FAFC),
                ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              // Top Innovation Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: ShapeDecoration(
                  color: isDark
                      ? const Color(0xFFFF5000).withValues(alpha: 0.15)
                      : const Color(0xFFFF5000).withValues(alpha: 0.1),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFF5000),
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ผู้ช่วยการเงินยุคใหม่ • PINGPAY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Color(0xFFFF5000),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Title & Slogan
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
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  height: 1.35,
                ),
              ),

              // Mascot Illustration with Gentle Floating Animation
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatingAnimation.value),
                        child: child,
                      );
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 340, maxWidth: 340),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.2 : 0.15),
                            blurRadius: 36,
                            offset: const Offset(0, 16),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/nong_ping_welcome.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 140,
                            height: 140,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5000),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 70,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Feature Highlights Row (3 Mini Pills)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeaturePill(Icons.document_scanner_rounded, 'AI สแกนบิล', isDark),
                  const SizedBox(width: 8),
                  _buildFeaturePill(Icons.qr_code_scanner_rounded, 'สแกนเพิ่มเพื่อน', isDark),
                  const SizedBox(width: 8),
                  _buildFeaturePill(Icons.security_rounded, 'ปลอดภัย 1 เครื่อง', isDark),
                ],
              ),

              const SizedBox(height: 20),

              // Interactive Swipe-Up Action Area
              GestureDetector(
                onTap: _scrollToLogin,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Up Chevron
                    AnimatedBuilder(
                      animation: _chevronAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _chevronAnimation.value),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Color(0xFFFF5000),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Primary Swipe-Up Pill Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: ShapeDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6A00), Color(0xFFFF4500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                          ),
                        ),
                        shadows: [
                          BoxShadow(
                            color: const Color(0xFFFF5000).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ปัดขึ้นเพื่อเริ่มต้นใช้งาน (Swipe Up)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW 2: PROFESSIONAL GOOGLE LOGIN SCREEN
  // =========================================================================
  Widget _buildLoginPage(BuildContext context, AuthState authState, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceBlack : const Color(0xFFF7F8FA),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              // Top Pull-Down Indicator to return to Welcome
              GestureDetector(
                onTap: _scrollToWelcome,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'แตะหรือปัดลงเพื่อกลับหน้าต้อนรับ',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Executive Login Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFEBEFF5),
                      width: 1,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: ShapeDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A00), Color(0xFFFF4500)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
                            ),
                          ),
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFFFF5000).withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'เข้าสู่ระบบ PingPay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'เชื่อมต่อบัญชี Google เพื่อใช้งานได้อย่างปลอดภัยและรวดเร็ว',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        height: 1.35,
                      ),
                    ),

                    // Session Notice (Single Device Kicked Out Warning)
                    if (authState.errorMessage != null && authState.errorMessage!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield_outlined, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 26),

                    // Professional Google Sign-In Button
                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleGoogleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                        foregroundColor: isDark ? Colors.white : const Color(0xFF1F1F1F),
                        elevation: isDark ? 0 : 2,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E6EC),
                          width: 1.2,
                        ),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

                    const SizedBox(height: 18),

                    // Security Badges List
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _buildSecurityCheck(
                            Icons.phonelink_lock_rounded,
                            'ความปลอดภัยสูงสุด จำกัด 1 เครื่องต่อบัญชี',
                            isDark,
                          ),
                          const SizedBox(height: 6),
                          _buildSecurityCheck(
                            Icons.verified_user_rounded,
                            'คุ้มครองข้อมูลส่วนบุคคลตามมาตรฐาน PDPA',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Footer Note
              Center(
                child: Text(
                  'PingPay Security System • 256-bit SSL Encryption',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white24 : AppColors.inkMuted48,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFEBEFF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFFF5000)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCheck(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF34C759)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

/// Official Vector Painter for Google G Logo
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
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -0.5,
        1.0,
        false,
      )
      ..lineTo(center.dx + radius * 0.5, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius * 0.55),
        0.5,
        -1.0,
        false,
      )
      ..close();
    canvas.drawPath(blueArc, bluePaint);

    // Outer Arc - Green
    final greenArc = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        0.5,
        1.1,
        false,
      )
      ..lineTo(center.dx - radius * 0.3, center.dy + radius * 0.4)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius * 0.55),
        1.6,
        -1.1,
        false,
      )
      ..close();
    canvas.drawPath(greenArc, greenPaint);

    // Outer Arc - Yellow
    final yellowArc = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        1.6,
        1.5,
        false,
      )
      ..lineTo(center.dx - radius * 0.5, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius * 0.55),
        3.1,
        -1.5,
        false,
      )
      ..close();
    canvas.drawPath(yellowArc, yellowPaint);

    // Outer Arc - Red
    final redArc = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        3.1,
        1.6,
        false,
      )
      ..lineTo(center.dx + radius * 0.3, center.dy - radius * 0.4)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius * 0.55),
        4.7,
        -1.6,
        false,
      )
      ..close();
    canvas.drawPath(redArc, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
