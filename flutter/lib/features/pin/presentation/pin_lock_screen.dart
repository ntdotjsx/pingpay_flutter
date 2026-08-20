import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/custom_pin_keypad.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _pin = '';
  String? _errorMessage;
  bool _isVerifying = false;

  void _onDigitPressed(String digit) {
    if (_isVerifying) return;

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
    if (_isVerifying) return;

    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin(String pin) async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authStateProvider.notifier).verifyPin(pin);
      if (!success && mounted) {
        setState(() {
          _errorMessage = 'รหัส PIN ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง';
          _isVerifying = false;
          _pin = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isVerifying = false;
          _pin = '';
        });
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // PingPay Lock Icon Badge
              Container(
                width: 64,
                height: 64,
                decoration: ShapeDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5000), Color(0xFFFF6A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shadows: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 22, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'ยินดีต้อนรับกลับ, ${user?.displayName ?? 'คุณ'}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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

              const SizedBox(height: 24),

              // PIN Dots Indicator
              PinDotsIndicator(
                pinLength: 6,
                filledLength: _pin.length,
                hasError: _errorMessage != null,
              ),

              const SizedBox(height: 10),

              // Error or Loading indicator
              SizedBox(
                height: 32,
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

              const Spacer(),

              // Custom Keypad
              CustomPinKeypad(
                onDigitPressed: _onDigitPressed,
                onDeletePressed: _onDeletePressed,
              ),

              const SizedBox(height: 16),

              // Logout Option
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.inkMuted48),
                label: const Text(
                  'เข้าสู่ระบบด้วยบัญชีอื่น (Logout)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMuted48,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

