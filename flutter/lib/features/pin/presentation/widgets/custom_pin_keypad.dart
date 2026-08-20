import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class PinDotsIndicator extends StatelessWidget {
  final int pinLength;
  final int filledLength;
  final bool hasError;

  const PinDotsIndicator({
    super.key,
    this.pinLength = 6,
    required this.filledLength,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pinLength, (index) {
        final isFilled = index < filledLength;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? AppColors.error
                : (isFilled
                    ? AppColors.primary
                    : (isDark ? Colors.white24 : const Color(0xFFE2E4EA))),
            border: Border.all(
              color: hasError
                  ? AppColors.error
                  : (isFilled
                      ? AppColors.primary
                      : (isDark ? Colors.white38 : const Color(0xFFCBD0DC))),
              width: 1.5,
            ),
            boxShadow: isFilled && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class CustomPinKeypad extends StatelessWidget {
  final void Function(String digit) onDigitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onBiometricPressed;
  final bool showBiometric;

  const CustomPinKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.onBiometricPressed,
    this.showBiometric = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildKeyRow(['1', '2', '3'], isDark),
        const SizedBox(height: 12),
        _buildKeyRow(['4', '5', '6'], isDark),
        const SizedBox(height: 12),
        _buildKeyRow(['7', '8', '9'], isDark),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left Action (Biometric or Empty)
            if (showBiometric && onBiometricPressed != null)
              _buildActionButton(
                icon: Icons.fingerprint_rounded,
                onPressed: onBiometricPressed!,
                isDark: isDark,
              )
            else
              const SizedBox(width: 72, height: 72),

            // Number 0
            _buildKeypadButton('0', isDark),

            // Right Action (Backspace / Delete)
            _buildActionButton(
              icon: Icons.backspace_outlined,
              onPressed: () {
                HapticFeedback.lightImpact();
                onDeletePressed();
              },
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d, isDark)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onDigitPressed(digit);
        },
        customBorder: const CircleBorder(),
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        highlightColor: AppColors.primary.withValues(alpha: 0.1),
        child: Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? AppColors.surfaceTile2
                : const Color(0xFFF4F6F9),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE9ECF2),
              width: 1,
            ),
          ),
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        child: Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 26,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
