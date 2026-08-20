import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/payment_models.dart';
import '../../services/debt_age_calculator.dart';

class ReceivableFriendCard extends StatelessWidget {
  final ReceivableFriendModel friend;
  final VoidCallback? onTap;

  const ReceivableFriendCard({super.key, required this.friend, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oldestAgeText = DebtAgeCalculator.formatDebtAgeThai(
      friend.oldestDebtStartDate,
    );
    final formattedDate = DebtAgeCalculator.formatThaiDate(
      friend.oldestDebtStartDate,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.hairline,
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Debtor Avatar + Name + Count of outstanding bills
                Row(
                  children: [
                    _buildAvatar(isDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.debtor.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.bodyOnDark
                                  : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${friend.outstandingBillCount} รายการค้างชำระ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.bodyMuted
                                  : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge if pending confirmation
                    if (friend.latestPaymentStatus ==
                        'pending_owner_confirmation')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'รอยืนยันสลิป',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white10 : AppColors.dividerSoft,
                ),
                const SizedBox(height: 12),

                // Financial Breakdown Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ติดเรา',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMuted48,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '฿${friend.totalOutstandingAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    if (friend.totalAmountPaid > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'จ่ายแล้ว',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted48,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '฿${friend.totalAmountPaid.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.bodyOnDark
                                  : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Bottom row: Debt age and tap for details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppColors.inkMuted48,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$oldestAgeText • ตั้งแต่ $formattedDate',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'ดูรายละเอียด',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.primaryOnDark
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.primaryOnDark
                              : AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Container(
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.6),
          ),
        ),
      ),
      child: ClipSmoothRect(
        radius: const SmoothBorderRadius.all(
          SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.6),
        ),
        child: (friend.debtor.avatarUrl != null &&
                friend.debtor.avatarUrl!.trim().isNotEmpty)
            ? Image.network(
                friend.debtor.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    friend.debtor.displayName.isNotEmpty
                        ? friend.debtor.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  friend.debtor.displayName.isNotEmpty
                      ? friend.debtor.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}
