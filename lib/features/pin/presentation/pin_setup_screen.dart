import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/custom_pin_keypad.dart';

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
        setState(() {
          _isVerifyingCurrent = false;
          _isSubmitting = false;
          _errorMessage = null;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'รหัส PIN ปัจจุบันไม่ถูกต้อง';
          _currentPin = '';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
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
      setState(() {
        _errorMessage = 'รหัส PIN ยืนยันไม่ตรงกัน กรุณาลองใหม่อีกครั้ง';
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

    if (_isVerifyingCurrent) {
      screenTitle = 'กรอกรหัส PIN เดิม 6 หลัก';
      screenSubtitle = 'เพื่อยืนยันตัวตนก่อนตั้งค่ารหัส PIN ใหม่';
    } else if (_isConfirming) {
      screenTitle = 'ยืนยันรหัส PIN 6 หลักอีกครั้ง';
      screenSubtitle = 'กรอกรหัส PIN ใหม่เดิมเพื่อยืนยันความถูกต้อง';
    } else {
      screenTitle = _isChangeMode ? 'สร้างรหัส PIN 6 หลักใหม่' : 'สร้างรหัส PIN 6 หลักของคุณ';
      screenSubtitle = 'รหัส PIN นี้จะใช้ในการยืนยันตัวตนและการทำธุรกรรมทางการเงิน';
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
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
                  Text(
                    _isChangeMode ? 'เปลี่ยนรหัส PIN' : 'ตั้งรหัสความปลอดภัย',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Security Icon Squircle Badge
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
                Icons.shield_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Text(
              screenTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                screenSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
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

            const SizedBox(height: 10),

            // Error message or loading
            SizedBox(
              height: 32,
              child: Center(
                child: (authState.isLoading || _isSubmitting)
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

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

