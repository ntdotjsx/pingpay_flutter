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
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_received_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'เพื่อนติดเรา',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: debtorCount > 0
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark
                            ? AppColors.surfaceTile2
                            : AppColors.canvasParchment),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$debtorCount คน',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: debtorCount > 0
                        ? AppColors.primary
                        : AppColors.inkMuted48,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCounterText(
            value: totalOutstandingAmount,
            prefix: '฿',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.8,
              color: totalOutstandingAmount > 0
                  ? (isDark ? Colors.white : AppColors.ink)
                  : AppColors.inkMuted48,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ยอดที่ยังไม่ได้รับ (เพื่อนยังค้างชำระ)',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            ),
          ),
        ],
      ),
    );
  }
}
