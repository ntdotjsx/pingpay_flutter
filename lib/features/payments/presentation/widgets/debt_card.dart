import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../friends/providers/friend_nickname_provider.dart';
import '../../models/payment_models.dart';
import '../../services/debt_age_calculator.dart';
import 'debt_acknowledgement_detail_sheet.dart';

class DebtCard extends ConsumerWidget {
  final DebtItemModel debt;
  final VoidCallback onPayTap;

  const DebtCard({super.key, required this.debt, required this.onPayTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtAgeText = DebtAgeCalculator.formatDebtAgeThai(debt.debtStartDate);
    final formattedDate = DebtAgeCalculator.formatThaiDate(debt.debtStartDate);
    final days = DebtAgeCalculator.calculateDaysOutstanding(debt.debtStartDate);

    final nicknamesMap = ref.watch(friendNicknameProvider);
    final creditorNick = nicknamesMap[debt.creditor.id] ?? nicknamesMap[debt.creditor.userCode];
    final hasCreditorNick = creditorNick != null && creditorNick.trim().isNotEmpty;
    final effectiveCreditorName = hasCreditorNick ? creditorNick : debt.creditor.displayName;

    // Dynamic urgency coloring for debt age badge
    final Color ageBadgeColor = days >= 30
        ? const Color(0xFFFF3B30)
        : (days >= 7 ? const Color(0xFFFF9500) : const Color(0xFFFF5000));

    return Material(
      color: isDark ? AppColors.surfaceTile1 : Colors.white,
      child: InkWell(
        onTap: onPayTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Creditor Squircle Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: ShapeDecoration(
                      color: isDark
                          ? const Color(0xFF2C2D32)
                          : const Color(0xFFFFECE5),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: ClipSmoothRect(
                      radius: const SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.8),
                      ),
                      child: debt.creditor.avatarUrl != null &&
                              debt.creditor.avatarUrl!.isNotEmpty
                          ? Image.network(
                              debt.creditor.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildAvatarInitial(effectiveCreditorName, isDark),
                            )
                          : _buildAvatarInitial(effectiveCreditorName, isDark),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 2. Middle Content (Name, Bill, Status, Date)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Creditor Name + Status Badge
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                effectiveCreditorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: isDark
                                      ? AppColors.bodyOnDark
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                            if (hasCreditorNick) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${debt.creditor.displayName})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            _buildStatusBadge(context),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Bill Title
                        Text(
                          debt.billTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted80,
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Date & Debt Age
                        Row(
                          children: [
                            Text(
                              debtAgeText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ageBadgeColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• $formattedDate',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? AppColors.bodyMuted
                                    : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ),

                        // Partial Progress indicator
                        if (debt.isPartiallyPaid) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: debt.paymentProgress,
                              minHeight: 3,
                              backgroundColor: isDark
                                  ? Colors.white12
                                  : const Color(0xFFF0F2F5),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF34C759),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 3. Right: Amount & Action Button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ค้าง ฿${debt.outstandingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: Color(0xFFFF5000),
                        ),
                      ),
                      if (debt.amountPaid > 0) ...[
                        const SizedBox(height: 1),
                        Text(
                          'ชำระแล้ว ฿${debt.amountPaid.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),

                      // Action Button
                      if (!debt.isAcknowledged && debt.outstandingAmount > 0)
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            DebtAcknowledgementDetailSheet.show(context, debt);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ตรวจสอบ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF9500),
                              ),
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onPayTap();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5000),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.payment_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'จ่ายเงิน',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Inset Divider
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 68,
              color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(String effectiveCreditorName, bool isDark) {
    return Center(
      child: Text(
        effectiveCreditorName.isNotEmpty
            ? effectiveCreditorName[0].toUpperCase()
            : 'U',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFFF6A00) : const Color(0xFFFF5000),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    if (debt.status == 'paid') {
      bg = const Color(0xFF34C759).withValues(alpha: 0.12);
      fg = const Color(0xFF34C759);
      label = 'ชำระครบ';
    } else if (debt.latestPaymentStatus == 'pending_owner_confirmation' ||
        debt.latestPaymentStatus == 'pending_approval') {
      bg = const Color(0xFF007AFF).withValues(alpha: 0.12);
      fg = const Color(0xFF007AFF);
      label = 'รอยืนยัน';
    } else if (debt.isPartiallyPaid) {
      bg = const Color(0xFFFF9500).withValues(alpha: 0.12);
      fg = const Color(0xFFFF9500);
      label = 'ชำระบางส่วน';
    } else {
      bg = const Color(0xFFFF3B30).withValues(alpha: 0.1);
      fg = const Color(0xFFFF3B30);
      label = 'ยังไม่ชำระ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
