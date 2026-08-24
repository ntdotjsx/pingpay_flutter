import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/animations/animated_pressable.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/payment_models.dart';
import '../../services/debt_age_calculator.dart';
import 'debt_acknowledgement_detail_sheet.dart';

class DebtCard extends StatelessWidget {
  final DebtItemModel debt;
  final VoidCallback onPayTap;

  const DebtCard({super.key, required this.debt, required this.onPayTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtAgeText = DebtAgeCalculator.formatDebtAgeThai(debt.debtStartDate);
    final formattedDate = DebtAgeCalculator.formatThaiDate(debt.debtStartDate);
    final days = DebtAgeCalculator.calculateDaysOutstanding(debt.debtStartDate);

    // Dynamic urgency coloring for debt age badge
    final Color ageBadgeColor = days >= 30
        ? const Color(0xFFFF3B30)
        : (days >= 7 ? const Color(0xFFFF9500) : const Color(0xFFFF5000));

    return AnimatedPressable(
      onTap: onPayTap,
      scaleDown: 0.985,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          shape: SmoothRectangleBorder(
            side: BorderSide(
              color: isDark ? Colors.white10 : const Color(0xFFEBEFF5),
              width: 1,
            ),
            borderRadius: const SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
            ),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Creditor Info & Status Badge
            Row(
              children: [
                // Creditor Squircle Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: ShapeDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A00), Color(0xFFFF4500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.7),
                      ),
                    ),
                  ),
                  child: ClipSmoothRect(
                    radius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.7),
                    ),
                    child: debt.creditor.avatarUrl != null &&
                            debt.creditor.avatarUrl!.isNotEmpty
                        ? Image.network(
                            debt.creditor.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarInitial(debt),
                          )
                        : _buildAvatarInitial(debt),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'คุณต้องจ่ายให้',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                      Text(
                        debt.creditor.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(context),
              ],
            ),

            const SizedBox(height: 14),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
            ),
            const SizedBox(height: 14),

            // 2. Body: Bill Title & Outstanding Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.billTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Date & Debt Age
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: ageBadgeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            debtAgeText,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: ageBadgeColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '• $formattedDate',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ค้าง ฿${debt.outstandingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Color(0xFFFF5000),
                      ),
                    ),
                    if (debt.amountPaid > 0)
                      Text(
                        'ชำระแล้ว ฿${debt.amountPaid.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Partial Payment Progress Bar
            if (debt.isPartiallyPaid) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: debt.paymentProgress,
                  minHeight: 4.5,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFF0F2F5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ชำระแล้ว ฿${debt.amountPaid.toStringAsFixed(2)} / ฿${debt.currentAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                  ),
                  Text(
                    '${(debt.paymentProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // 3. Action Area
            if (!debt.isAcknowledged && debt.outstandingAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFFF9500)),
                        SizedBox(width: 4),
                        Text(
                          'รอตรวจสอบและยอมรับ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF9500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => DebtAcknowledgementDetailSheet.show(context, debt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9500),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_rounded, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'ตรวจสอบและยอมรับ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: onPayTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5000),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: const Color(0xFFFF5000).withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'จ่ายเงิน',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(DebtItemModel debt) {
    return Center(
      child: Text(
        debt.creditor.displayName.isNotEmpty
            ? debt.creditor.displayName[0].toUpperCase()
            : 'U',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
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
      label = 'ชำระครบแล้ว';
    } else if (debt.latestPaymentStatus == 'pending_owner_confirmation' ||
        debt.latestPaymentStatus == 'pending_approval') {
      bg = const Color(0xFF007AFF).withValues(alpha: 0.12);
      fg = const Color(0xFF007AFF);
      label = 'รอยืนยันสลิป';
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
