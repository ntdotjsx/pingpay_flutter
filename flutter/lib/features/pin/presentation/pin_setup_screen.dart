import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';

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

  void _handlePinCompleted(String value) {
    if (!_isConfirming) {
      setState(() {
        _pin = value;
        _isConfirming = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _confirmPin = value;
      });
      _submitPin();
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

    try {
      await ref.read(authStateProvider.notifier).setupPin(_pin);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isConfirming = false;
        _pin = '';
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งรหัสความปลอดภัย PIN'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _isConfirming
                    ? 'ยืนยันรหัส PIN 6 หลักอีกครั้ง'
                    : 'สร้างรหัส PIN 6 หลักของคุณ',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isConfirming
                    ? 'กรอกรหัส PIN เดิมเพื่อยืนยันความถูกต้อง'
                    : 'รหัส PIN นี้จะใช้ในการยืนยันตัวตนและการทำธุรกรรมทางการเงิน',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),

              Pinput(
                key: ValueKey(_isConfirming),
                length: 6,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                ),
                onCompleted: _handlePinCompleted,
              ),
              const SizedBox(height: AppSpacing.xl),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (authState.isLoading) const CircularProgressIndicator(),

              if (_isConfirming && !authState.isLoading) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isConfirming = false;
                      _pin = '';
                      _confirmPin = '';
                      _errorMessage = null;
                    });
                  },
                  child: const Text('ย้อนกลับไปตั้งรหัส PIN ใหม่'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
