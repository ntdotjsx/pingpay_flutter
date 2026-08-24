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
      padding: const EdgeInsets.all(22),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark
                ? Colors.white10
                : const Color(0xFFFF5000).withValues(alpha: 0.15),
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFFFF5000),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ยอดที่เราต้องชำระ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: outstandingCount > 0
                      ? const Color(0xFFFF5000).withValues(alpha: 0.12)
                      : const Color(0xFF34C759).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  outstandingCount > 0
                      ? '$outstandingCount รายการค้าง'
                      : 'ไม่มีหนี้ค้าง 🎉',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: outstandingCount > 0
                        ? const Color(0xFFFF5000)
                        : const Color(0xFF34C759),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Large Balance Number
          AnimatedCounterText(
            value: totalOutstandingAmount,
            prefix: '฿',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),

          const SizedBox(height: 4),

          // Subtitle
          Text(
            'ยอดหนี้ค้างชำระทั้งหมดที่ต้องโอนคืนเพื่อน',
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
