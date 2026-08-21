import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/theme.dart';

class DestructiveConfirmationSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final int? itemCount;
  final double? totalAmount;
  final IconData icon;

  const DestructiveConfirmationSheet({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'ลบรายการ',
    this.cancelLabel = 'ยกเลิก',
    required this.onConfirm,
    this.itemCount,
    this.totalAmount,
    this.icon = Icons.warning_amber_rounded,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'ลบรายการ',
    String cancelLabel = 'ยกเลิก',
    int? itemCount,
    double? totalAmount,
    IconData icon = Icons.warning_amber_rounded,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DestructiveConfirmationSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        itemCount: itemCount,
        totalAmount: totalAmount,
        icon: icon,
        onConfirm: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(ctx, true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Warning Icon
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.error, size: 30),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.inkMuted48,
                height: 1.4,
              ),
            ),

            // Metadata card if provided
            if (itemCount != null || totalAmount != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: ShapeDecoration(
                  color: isDark
                      ? AppColors.surfaceTile2
                      : AppColors.canvasParchment,
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (itemCount != null)
                      Column(
                        children: [
                          const Text(
                            'จำนวนรายการ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted48,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$itemCount รายการ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    if (itemCount != null && totalAmount != null)
                      Container(
                        width: 1,
                        height: 24,
                        color: AppColors.hairline,
                      ),
                    if (totalAmount != null)
                      Column(
                        children: [
                          const Text(
                            'ยอดรวม',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted48,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '฿${totalAmount!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.bodyOnDark
                          : AppColors.ink,
                      side: BorderSide(
                        color: isDark ? Colors.white12 : AppColors.hairline,
                      ),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
