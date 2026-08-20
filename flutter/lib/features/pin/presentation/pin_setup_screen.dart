import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/custom_pin_keypad.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (!_isConfirming) {
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
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
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

    try {
      await ref.read(authStateProvider.notifier).setupPin(_pin);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _isConfirming = false;
        _pin = '';
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLength = _isConfirming ? _confirmPin.length : _pin.length;

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
                  else
                    const SizedBox(width: 48),
                  const Text(
                    'ตั้งรหัสความปลอดภัย',
                    style: TextStyle(
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
              _isConfirming
                  ? 'ยืนยันรหัส PIN 6 หลักอีกครั้ง'
                  : 'สร้างรหัส PIN 6 หลักของคุณ',
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
                _isConfirming
                    ? 'กรอกรหัส PIN เดิมเพื่อยืนยันความถูกต้อง'
                    : 'รหัส PIN นี้จะใช้ในการยืนยันตัวตนและการทำธุรกรรมทางการเงิน',
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
                child: authState.isLoading
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

