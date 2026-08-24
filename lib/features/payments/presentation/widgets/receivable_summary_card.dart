import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import '../../../../core/animations/animated_counter_text.dart';
import '../../../../core/theme/app_colors.dart';

class ReceivableSummaryCard extends StatelessWidget {
  final int debtorCount;
  final double totalOutstandingAmount;
  final String currency;
  final VoidCallback? onRefresh;

  const ReceivableSummaryCard({
    super.key,
    required this.debtorCount,
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
                : const Color(0xFF34C759).withValues(alpha: 0.2),
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
                      color: const Color(0xFF34C759).withValues(alpha: 0.12),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.call_received_rounded,
                      color: Color(0xFF34C759),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ยอดที่เพื่อนติดเรา',
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
                  color: debtorCount > 0
                      ? const Color(0xFF34C759).withValues(alpha: 0.12)
                      : (isDark ? AppColors.surfaceTile2 : const Color(0xFFF4F6F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  debtorCount > 0 ? '$debtorCount คนค้างชำระ' : 'ไม่มีลูกหนี้ค้าง 🎉',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: debtorCount > 0
                        ? const Color(0xFF34C759)
                        : AppColors.inkMuted48,
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
            'ยอดเงินทั้งหมดที่เพื่อนกำลังรอชำระคืนคุณ',
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
