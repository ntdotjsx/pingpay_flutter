import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/custom_pin_keypad.dart';
import 'widgets/forgot_pin_bottom_sheet.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _errorMessage;
  bool _isVerifying = false;
  bool _isLockedOut = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Sine wave oscillation for realistic haptic shake
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14.0, end: 14.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isVerifying || _isLockedOut) return;

    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
        _errorMessage = null;
      });

      if (_pin.length == 6) {
        _verifyPin(_pin);
      }
    }
  }

  void _onDeletePressed() {
    if (_isVerifying || _isLockedOut) return;

    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _triggerShakeAndReset(String message, {bool isLockout = false}) async {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
    setState(() {
      _errorMessage = message;
      _isVerifying = false;
      if (isLockout) {
        _isLockedOut = true;
      }
    });

    // Pause briefly to show the red dots shaking, then reset for typing
    await Future.delayed(const Duration(milliseconds: 550));
    if (mounted) {
      setState(() {
        _pin = '';
      });

      if (isLockout) {
        _showLockoutDialog();
      }
    }
  }

  void _showLockoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('บัญชีถูกล็อกชั่วคราว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'คุณกรอกรหัส PIN ผิดครบ 3 ครั้ง เพื่อความปลอดภัย กรุณายืนยันรหัส OTP ผ่าน Email เพื่อรีเซ็ตรหัส PIN ใหม่',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ForgotPinBottomSheet.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('ยืนยัน Email และตั้ง PIN ใหม่', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPin(String pin) async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authStateProvider.notifier).verifyPin(pin);
      if (success && mounted) {
        HapticFeedback.lightImpact();
        context.go('/home');
      } else if (!success && mounted) {
        await _triggerShakeAndReset('รหัส PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง');
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception:', '').trim();
        final isLockout = errText.contains('ล็อก') || errText.contains('LOCKED') || errText.contains('ครบ 3 ครั้ง');
        await _triggerShakeAndReset(errText, isLockout: isLockout);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Profile Avatar Container with Squircle & Lock Indicator
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF5000).withValues(alpha: 0.15),
                      shadows: [
                        BoxShadow(
                          color: const Color(0xFFFF5000).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      shape: SmoothRectangleBorder(
                        side: BorderSide(
                          color: isDark ? AppColors.surfaceTile2 : Colors.white,
                          width: 2.5,
                        ),
                        borderRadius: const SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 26, cornerSmoothing: 0.6),
                        ),
                      ),
                    ),
                    child: ClipSmoothRect(
                      radius: const SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 26, cornerSmoothing: 0.6),
                      ),
                      child: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                          ? Image.network(
                              user.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildUserInitial(user.displayName ?? 'PingPay', 76),
                            )
                          : _buildUserInitial(user?.displayName ?? 'PingPay', 76),
                    ),
                  ),

                  // Mini Lock Status Badge
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5000), Color(0xFFFF6A00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.surfaceBlack : AppColors.canvas,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                'ยินดีต้อนรับกลับ, ${user?.displayName ?? 'คุณ'}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'กรุณาระบุรหัส PIN 6 หลักเพื่อเข้าใช้งาน PingPay',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ),

              const SizedBox(height: 20),

              // PIN Dots Indicator with Shake Animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: PinDotsIndicator(
                  pinLength: 6,
                  filledLength: _pin.length,
                  hasError: _errorMessage != null,
                ),
              ),

              const SizedBox(height: 8),

              // Error or Loading indicator
              SizedBox(
                height: 28,
                child: Center(
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : (_errorMessage != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : const SizedBox.shrink()),
                ),
              ),

              const Spacer(flex: 3),

              // Custom Keypad or Lockout Card
              if (_isLockedOut)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile1 : Colors.white,
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.8),
                      ),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.error.withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.lock_rounded, color: AppColors.error, size: 26),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'บัญชีถูกระงับชั่วคราว',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'คุณกรอก PIN ผิดครบ 3 ครั้ง กรุณายืนยันรหัส OTP ผ่าน Email เพื่อปลดล็อกและตั้งรหัส PIN ใหม่',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () => ForgotPinBottomSheet.show(context),
                          icon: const Icon(Icons.mail_outline_rounded, size: 18),
                          label: const Text('ปลดล็อกด้วย Email OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5000),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                CustomPinKeypad(
                  onDigitPressed: _onDigitPressed,
                  onDeletePressed: _onDeletePressed,
                ),

              const Spacer(flex: 1),

              // Forgot PIN & Logout Options
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      ForgotPinBottomSheet.show(context);
                    },
                    child: const Text(
                      'ลืมรหัส PIN?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFF5000),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white38 : AppColors.inkMuted48,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(authStateProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 14, color: AppColors.inkMuted48),
                    label: const Text(
                      'ออกจากระบบ (Logout)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted48,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInitial(String name, double size) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFFF5000).withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFF5000),
        ),
      ),
    );
  }
}

