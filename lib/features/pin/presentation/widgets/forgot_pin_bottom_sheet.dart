import 'dart:async';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/services/google_auth_service.dart';
import 'custom_pin_keypad.dart';

enum ForgotPinStep { requestOtp, enterOtp, setNewPin, confirmNewPin }

class ForgotPinBottomSheet extends ConsumerStatefulWidget {
  const ForgotPinBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ForgotPinBottomSheet(),
    );
  }

  @override
  ConsumerState<ForgotPinBottomSheet> createState() => _ForgotPinBottomSheetState();
}

class _ForgotPinBottomSheetState extends ConsumerState<ForgotPinBottomSheet> {
  ForgotPinStep _step = ForgotPinStep.requestOtp;
  bool _isLoading = false;
  String? _errorMessage;
  String _maskedEmail = '';
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _showEmailInput = false;

  // Email input fallback if needed
  final TextEditingController _emailController = TextEditingController();

  // OTP
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  String _resetToken = '';

  // New PIN
  String _newPin = '';
  String _confirmPin = '';

  @override
  void initState() {
    super.initState();
    _autoResolveGoogleEmail();
  }

  Future<void> _autoResolveGoogleEmail() async {
    final user = ref.read(authStateProvider).user;
    if (user?.email != null && user!.email!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _maskedEmail = _maskEmail(user.email!);
        });
      }
      return;
    }

    try {
      final googleUser = GoogleAuthService.currentUser ?? await GoogleAuthService.signInSilently();
      if (googleUser?.email != null && googleUser!.email.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = googleUser.email;
          _maskedEmail = _maskEmail(googleUser.email);
        });
      }
    } catch (_) {}
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    final masked = name.length > 2 
      ? '${name.substring(0, 2)}${'*' * (name.length - 2)}'
      : '$name***';
    return '$masked@$domain';
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = seconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 1) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
      }
    });
  }

  Future<void> _requestOtp() async {
    String? targetEmail = _emailController.text.trim();
    if (targetEmail.isEmpty) {
      final user = ref.read(authStateProvider).user;
      if (user?.email != null && user!.email!.isNotEmpty) {
        targetEmail = user.email;
      } else {
        final googleUser = GoogleAuthService.currentUser ?? await GoogleAuthService.signInSilently();
        targetEmail = googleUser?.email;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.requestPinResetOtp(
        email: targetEmail != null && targetEmail.isNotEmpty ? targetEmail : null,
      );
      if (mounted) {
        setState(() {
          _maskedEmail = res['maskedEmail'] ?? (targetEmail != null ? _maskEmail(targetEmail) : '');
          _step = ForgotPinStep.enterOtp;
          _isLoading = false;
        });
        _startCooldown(res['cooldownSeconds'] ?? 60);
        AppToast.info(context, 'รหัส OTP ถูกส่งไปยัง $_maskedEmail แล้ว');
        Future.delayed(const Duration(milliseconds: 300), () {
          _otpFocusNode.requestFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '');
        final isNoEmail = errText.contains('NO_EMAIL') || errText.contains('ยังไม่มี Email');
        setState(() {
          _errorMessage = isNoEmail ? 'โปรดระบุ Email ของคุณเพื่อรับรหัส OTP' : errText;
          if (isNoEmail) {
            _showEmailInput = true;
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.verifyPinResetOtp(otp);
      if (mounted) {
        setState(() {
          _resetToken = res['resetToken'] ?? '';
          _step = ForgotPinStep.setNewPin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _otpController.clear();
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _onKeypadDigit(String digit) {
    setState(() {
      _errorMessage = null;
    });

    if (_step == ForgotPinStep.setNewPin) {
      if (_newPin.length < 6) {
        setState(() {
          _newPin += digit;
        });
        if (_newPin.length == 6) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) {
              setState(() {
                _step = ForgotPinStep.confirmNewPin;
              });
            }
          });
        }
      }
    } else if (_step == ForgotPinStep.confirmNewPin) {
      if (_confirmPin.length < 6) {
        setState(() {
          _confirmPin += digit;
        });
        if (_confirmPin.length == 6) {
          _submitNewPin();
        }
      }
    }
  }

  void _onKeypadDelete() {
    setState(() {
      _errorMessage = null;
    });

    if (_step == ForgotPinStep.setNewPin) {
      if (_newPin.isNotEmpty) {
        setState(() {
          _newPin = _newPin.substring(0, _newPin.length - 1);
        });
      }
    } else if (_step == ForgotPinStep.confirmNewPin) {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        });
      } else {
        // Back to step 1
        setState(() {
          _step = ForgotPinStep.setNewPin;
          _newPin = '';
        });
      }
    }
  }

  Future<void> _submitNewPin() async {
    if (_newPin != _confirmPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'รหัส PIN ไม่ตรงกัน กรุณาตั้งค่าใหม่อีกครั้ง';
        _confirmPin = '';
        _newPin = '';
        _step = ForgotPinStep.setNewPin;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.resetPinWithToken(resetToken: _resetToken, newPin: _newPin);
      if (mounted) {
        ref.read(authStateProvider.notifier).unlockApp();
        Navigator.of(context).pop();
        AppToast.success(context, 'ตั้งรหัส PIN ใหม่สำเร็จแล้ว 🎉');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _confirmPin = '';
          _newPin = '';
          _step = ForgotPinStep.setNewPin;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).user;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceBlack : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.7),
            ),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Header
              if (_step == ForgotPinStep.requestOtp) ...[
                _buildRequestOtpStep(isDark, user?.displayName ?? 'คุณ')
              ] else if (_step == ForgotPinStep.enterOtp) ...[
                _buildEnterOtpStep(isDark)
              ] else if (_step == ForgotPinStep.setNewPin || _step == ForgotPinStep.confirmNewPin) ...[
                _buildPinSetupStep(isDark)
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestOtpStep(bool isDark, String userName) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5000).withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFFFF5000), size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          'ลืมรหัส PIN?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ระบบจะส่งรหัส OTP 6 หลักไปยังอีเมลที่เชื่อมต่อไว้กับบัญชีของคุณ เพื่อยืนยันตัวตนก่อนตั้งรหัส PIN ใหม่',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            height: 1.4,
          ),
        ),
        if (_maskedEmail.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5000).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF5000).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle_outlined, size: 16, color: Color(0xFFFF5000)),
                const SizedBox(width: 6),
                Text(
                  _maskedEmail,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5000),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
        if (_showEmailInput) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
            decoration: InputDecoration(
              hintText: 'กรอกอีเมลของคุณ (เช่น name@gmail.com)',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFFF5000), size: 20),
              filled: true,
              fillColor: isDark ? AppColors.surfaceTile2 : const Color(0xFFF4F6F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E4EA),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E4EA),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFF5000),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5000),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text(
                    'ส่งรหัส OTP เข้า Email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEnterOtpStep(bool isDark) {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E4EA),
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: const Color(0xFFFF5000), width: 2),
        color: const Color(0xFFFF5000).withValues(alpha: 0.05),
      ),
    );

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5000).withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.password_rounded, color: Color(0xFFFF5000), size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          'กรอกรหัส OTP 6 หลัก',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'รหัสถูกส่งไปยัง $_maskedEmail แล้ว',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
          ),
        ),
        const SizedBox(height: 20),
        Pinput(
          length: 6,
          controller: _otpController,
          focusNode: _otpFocusNode,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onCompleted: (val) => _verifyOtp(val),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 20),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ไม่ได้รับรหัส OTP? ',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ),
              TextButton(
                onPressed: _cooldownSeconds > 0 ? null : _requestOtp,
                child: Text(
                  _cooldownSeconds > 0
                      ? 'ส่งใหม่อีกครั้ง ($_cooldownSeconds วินาที)'
                      : 'ส่งรหัสใหม่',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _cooldownSeconds > 0 ? AppColors.inkMuted48 : const Color(0xFFFF5000),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildPinSetupStep(bool isDark) {
    final isConfirming = _step == ForgotPinStep.confirmNewPin;
    final currentPinLength = isConfirming ? _confirmPin.length : _newPin.length;

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5000).withValues(alpha: 0.12),
          ),
          child: Icon(
            isConfirming ? Icons.check_circle_outline_rounded : Icons.lock_reset_rounded,
            color: const Color(0xFFFF5000),
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isConfirming ? 'ยืนยันรหัส PIN 6 หลักอีกครั้ง' : 'ตั้งรหัส PIN ใหม่ 6 หลัก',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isConfirming ? 'กรอกรหัส PIN เดิมซ้ำอีกครั้งเพื่อยืนยัน' : 'ระบุรหัสตัวเลข 6 หลักที่คุณจำได้',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
          ),
        ),
        const SizedBox(height: 16),
        PinDotsIndicator(
          pinLength: 6,
          filledLength: currentPinLength,
          hasError: _errorMessage != null,
        ),
        const SizedBox(height: 10),
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          )
        else
          const SizedBox(height: 18),
        const SizedBox(height: 8),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(),
          )
        else
          CustomPinKeypad(
            onDigitPressed: _onKeypadDigit,
            onDeletePressed: _onKeypadDelete,
          ),
      ],
    );
  }
}
