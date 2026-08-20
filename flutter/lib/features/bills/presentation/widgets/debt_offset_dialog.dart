import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../payments/models/payment_models.dart';

class DebtOffsetMatch {
  final String participantId;
  final String participantName;
  final double currentBillShare;
  final DebtItemModel existingDebt;
  final double offsetAmount;
  final double remainingShareAfterOffset;
  final double remainingDebtAfterOffset;

  DebtOffsetMatch({
    required this.participantId,
    required this.participantName,
    required this.currentBillShare,
    required this.existingDebt,
    required this.offsetAmount,
    required this.remainingShareAfterOffset,
    required this.remainingDebtAfterOffset,
  });
}

class DebtOffsetConfirmationDialog extends StatelessWidget {
  final List<DebtOffsetMatch> matches;
  final VoidCallback onConfirmOffset;
  final VoidCallback onSkipOffset;

  const DebtOffsetConfirmationDialog({
    super.key,
    required this.matches,
    required this.onConfirmOffset,
    required this.onSkipOffset,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<DebtOffsetMatch> matches,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DebtOffsetConfirmationDialog(
        matches: matches,
        onConfirmOffset: () => Navigator.pop(ctx, true),
        onSkipOffset: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalOffset = matches.fold(0.0, (sum, m) => sum + m.offsetAmount);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
            ),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon, Title & Close Button
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.6),
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_horizontal_circle_rounded,
                    color: Color(0xFFFF9500),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'พบรายการหนี้เดิมที่ติดเพื่อน',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ต้องการหักล้างหนี้อัตโนมัติหรือไม่?',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : AppColors.hairline.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'คุณมีหนี้เดิมที่ค้างจ่ายให้เพื่อนในบิลนี้ ระบบสามารถหักล้างยอดหนี้ตามจำนวนส่วนแบ่งได้ทันที (รวมหักล้าง ฿${totalOffset.toStringAsFixed(2)})',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Matches List
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: matches.map((m) => _buildMatchItem(context, m, isDark)).toList(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkipOffset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'ไม่หักล้าง (แยกบิล)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirmOffset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9500),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'หักล้างหนี้ทันที',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildMatchItem(BuildContext context, DebtOffsetMatch m, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile2 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Friend Name & Offset Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                m.participantName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'หักลบ: -฿${m.offsetAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: isDark ? Colors.white10 : AppColors.dividerSoft),
          const SizedBox(height: 8),

          // Detail rows
          _buildRow(
            '• หนี้เดิมที่คุณติด (${m.existingDebt.billTitle}):',
            '฿${m.existingDebt.outstandingAmount.toStringAsFixed(2)}',
            isDark,
          ),
          const SizedBox(height: 4),
          _buildRow(
            '• ยอดที่เพื่อนต้องหารในบิลนี้:',
            '฿${m.currentBillShare.toStringAsFixed(2)}',
            isDark,
          ),
          const SizedBox(height: 4),
          _buildRow(
            m.remainingShareAfterOffset > 0
                ? '➡️ เพื่อนยังต้องจ่ายคุณคงเหลือ:'
                : (m.remainingDebtAfterOffset > 0
                    ? '➡️ คุณยังคงค้างเพื่อนคงเหลือ:'
                    : '➡️ หนี้หักล้างกันหมดพอดี (฿0.00)'),
            m.remainingShareAfterOffset > 0
                ? '฿${m.remainingShareAfterOffset.toStringAsFixed(2)}'
                : (m.remainingDebtAfterOffset > 0
                    ? '฿${m.remainingDebtAfterOffset.toStringAsFixed(2)}'
                    : '฿0.00'),
            isDark,
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isHighlight
                  ? const Color(0xFFFF9500)
                  : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? const Color(0xFFFF9500)
                : (isDark ? AppColors.bodyOnDark : AppColors.ink),
          ),
        ),
      ],
    );
  }
}
