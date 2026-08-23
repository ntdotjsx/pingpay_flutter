import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/custom_pin_keypad.dart';
import 'widgets/forgot_pin_bottom_sheet.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _currentPin = '';
  String _pin = '';
  String _confirmPin = '';

  bool _isChangeMode = false;
  bool _isVerifyingCurrent = false;
  bool _isConfirming = false;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    if (user?.onboardingState == OnboardingState.completed) {
      _isChangeMode = true;
      _isVerifyingCurrent = true;
    }
  }

  void _onDigitPressed(String digit) {
    if (_isSubmitting) return;

    if (_isVerifyingCurrent) {
      if (_currentPin.length < 6) {
        setState(() {
          _currentPin += digit;
          _errorMessage = null;
        });

        if (_currentPin.length == 6) {
          _verifyCurrentPin();
        }
      }
    } else if (!_isConfirming) {
      if (_pin.length < 6) {
        setState(() {
          _pin += digit;
          _errorMessage = null;
        });

        if (_pin.length == 6) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) {
              setState(() {
                _isConfirming = true;
                _confirmPin = '';
              });
            }
          });
        }
      }
    } else {
      if (_confirmPin.length < 6) {
        setState(() {
          _confirmPin += digit;
          _errorMessage = null;
        });

        if (_confirmPin.length == 6) {
          _submitPin();
        }
      }
    }
  }

  void _onDeletePressed() {
    if (_isSubmitting) return;

    setState(() {
      _errorMessage = null;
      if (_isVerifyingCurrent) {
        if (_currentPin.isNotEmpty) {
          _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        }
      } else if (!_isConfirming) {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyCurrentPin() async {
    setState(() => _isSubmitting = true);
    try {
      final isValid = await ref.read(authRepositoryProvider).verifyPin(_currentPin);
      if (isValid && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isVerifyingCurrent = false;
          _isSubmitting = false;
          _errorMessage = null;
        });
      } else if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'รหัส PIN ปัจจุบันไม่ถูกต้อง กรุณาลองใหม่';
          _currentPin = '';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _currentPin = '';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitPin() async {
    if (_pin != _confirmPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'รหัส PIN ใหม่ยืนยันไม่ตรงกัน กรุณากรอกใหม่อีกครั้ง';
        _isConfirming = false;
        _pin = '';
        _confirmPin = '';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isChangeMode) {
        await ref.read(authStateProvider.notifier).changePin(
          currentPin: _currentPin.isNotEmpty ? _currentPin : null,
          newPin: _pin,
        );
        if (mounted) {
          HapticFeedback.mediumImpact();
          AppToast.success(context, 'เปลี่ยนรหัส PIN สำเร็จเรียบร้อยแล้ว');
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      } else {
        await ref.read(authStateProvider.notifier).setupPin(_pin);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isConfirming = false;
          _pin = '';
          _confirmPin = '';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canGoBack = Navigator.canPop(context);

    int currentLength;
    if (_isVerifyingCurrent) {
      currentLength = _currentPin.length;
    } else if (_isConfirming) {
      currentLength = _confirmPin.length;
    } else {
      currentLength = _pin.length;
    }

    String screenTitle;
    String screenSubtitle;
    int currentStep = 1;
    final int totalSteps = _isChangeMode ? 3 : 2;

    Color badgeColor = const Color(0xFFFF5000);
    IconData badgeIcon = Icons.shield_rounded;

    if (_isVerifyingCurrent) {
      currentStep = 1;
      badgeColor = const Color(0xFF007AFF);
      badgeIcon = Icons.lock_outline_rounded;
      screenTitle = 'กรอกรหัส PIN เดิม 6 หลัก';
      screenSubtitle = 'เพื่อยืนยันตัวตนก่อนตั้งค่ารหัส PIN ใหม่';
    } else if (_isConfirming) {
      currentStep = _isChangeMode ? 3 : 2;
      badgeColor = const Color(0xFF34C759);
      badgeIcon = Icons.check_circle_outline_rounded;
      screenTitle = 'ยืนยันรหัส PIN 6 หลักอีกครั้ง';
      screenSubtitle = 'กรอกรหัส PIN ใหม่อีกครั้งเพื่อยืนยันความถูกต้อง';
    } else {
      currentStep = _isChangeMode ? 2 : 1;
      badgeColor = const Color(0xFFFF5000);
      badgeIcon = Icons.vpn_key_rounded;
      screenTitle = _isChangeMode ? 'สร้างรหัส PIN 6 หลักใหม่' : 'สร้างรหัส PIN 6 หลักของคุณ';
      screenSubtitle = 'รหัส PIN จะใช้ยืนยันธุรกรรมและการเงินในแอป';
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFFAFBFD),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar & Step Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isConfirming)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () {
                        setState(() {
                          _isConfirming = false;
                          _pin = '';
                          _confirmPin = '';
                          _errorMessage = null;
                        });
                      },
                    )
                  else if (canGoBack)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 48),

                  // Header Title & Step Counter Pill
                  Column(
                    children: [
                      Text(
                        _isChangeMode ? 'เปลี่ยนรหัส PIN' : 'ตั้งรหัสความปลอดภัย',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'ขั้นตอนที่ $currentStep / $totalSteps',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Animated Security Icon Squircle Badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 68,
              height: 68,
              decoration: ShapeDecoration(
                gradient: LinearGradient(
                  colors: [badgeColor, badgeColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shadows: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: isDark ? 0.4 : 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
                  ),
                ),
              ),
              child: Icon(
                badgeIcon,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Text(
              screenTitle,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                screenSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // PIN Dots Indicator
            PinDotsIndicator(
              pinLength: 6,
              filledLength: currentLength,
              hasError: _errorMessage != null,
            ),

            const SizedBox(height: 12),

            // Error message or loading status
            SizedBox(
              height: 36,
              child: Center(
                child: (authState.isLoading || _isSubmitting)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : (_errorMessage != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
            ),

            // Forgot PIN Shortcut Button (Only on Step 1: Verify Current PIN)
            if (_isVerifyingCurrent) ...[
              TextButton.icon(
                onPressed: () => ForgotPinBottomSheet.show(context),
                icon: const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFF007AFF)),
                label: const Text(
                  'ลืมรหัส PIN ปัจจุบัน? (รีเซ็ตผ่านอีเมล)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],

            const Spacer(),

            // Custom Keypad
            CustomPinKeypad(
              onDigitPressed: _onDigitPressed,
              onDeletePressed: _onDeletePressed,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

