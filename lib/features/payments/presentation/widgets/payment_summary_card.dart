import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import '../../../../core/animations/animated_counter_text.dart';
import '../../../../core/theme/app_colors.dart';

class PaymentSummaryCard extends StatelessWidget {
  final int outstandingCount;
  final double totalOutstandingAmount;
  final String currency;
  final VoidCallback? onRefresh;

  const PaymentSummaryCard({
    super.key,
    required this.outstandingCount,
    required this.totalOutstandingAmount,
    this.currency = 'THB',
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.hairline,
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 22, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ค้างชำระ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.bodyMuted
                          : AppColors.inkMuted80,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 12, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Text(
                  '$outstandingCount รายการ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedCounterText(
            value: totalOutstandingAmount,
            prefix: '฿',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ยอดที่ต้องชำระทั้งหมด',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            ),
          ),
        ],
      ),
    );
  }
}
