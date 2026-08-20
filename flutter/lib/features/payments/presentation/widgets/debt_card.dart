import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        ? AppColors.error
        : (days >= 7 ? AppColors.warning : AppColors.primary);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.hairline,
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPayTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Creditor Info & Status Badge
                Row(
                  children: [
                    // Creditor Squircle Avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: ShapeDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.6),
                          ),
                        ),
                      ),
                      child: ClipSmoothRect(
                        radius: const SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.6),
                        ),
                        child: debt.creditor.avatarUrl != null && debt.creditor.avatarUrl!.isNotEmpty
                            ? Image.network(
                                debt.creditor.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    debt.creditor.displayName.isNotEmpty
                                        ? debt.creditor.displayName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  debt.creditor.displayName.isNotEmpty
                                      ? debt.creditor.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'คุณต้องจ่ายให้',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.bodyMuted
                                  : AppColors.inkMuted48,
                            ),
                          ),
                          Text(
                            debt.creditor.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.bodyOnDark
                                  : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(context),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white10 : AppColors.hairline,
                ),
                const SizedBox(height: 12),

                // Body: Bill Title & Outstanding Amount (Strong Typography)
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.bodyOnDark
                                  : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ageBadgeColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• $formattedDate',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.bodyMuted
                                      : AppColors.inkMuted48,
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
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        if (debt.amountPaid > 0)
                          Text(
                            'ชำระแล้ว ฿${debt.amountPaid.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.bodyMuted
                                  : AppColors.inkMuted48,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Partial Payment Progress Bar
                if (debt.isPartiallyPaid) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: debt.paymentProgress,
                      minHeight: 4,
                      backgroundColor: isDark
                          ? Colors.white12
                          : AppColors.dividerSoft,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ชำระแล้ว ฿${debt.amountPaid.toStringAsFixed(2)} / ฿${debt.currentAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.bodyMuted
                              : AppColors.inkMuted48,
                        ),
                      ),
                      Text(
                        '${(debt.paymentProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.bodyMuted
                              : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Action Area: Verify & Acknowledge (if not yet acknowledged) OR Pay Button (if acknowledged)
                if (!debt.isAcknowledged && debt.outstandingAmount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
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
                                fontWeight: FontWeight.w600,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'ตรวจสอบและยอมรับ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payment_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'จ่ายเงิน',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildStatusBadge(BuildContext context) {
    String label;
    Color color;

    if (debt.latestPaymentStatus == 'pending_owner_confirmation') {
      label = 'รอยืนยันการรับเงิน';
      color = AppColors.warning;
    } else if (debt.status == 'paid' || debt.outstandingAmount <= 0) {
      label = 'ชำระครบแล้ว';
      color = AppColors.success;
    } else if (debt.status == 'written_off') {
      label = 'ตัดหนี้แล้ว';
      color = AppColors.inkMuted48;
    } else if (debt.isPartiallyPaid) {
      label = 'ชำระบางส่วน';
      color = AppColors.warning;
    } else {
      label = 'ยังไม่ชำระ';
      color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class SwipeToAcknowledgeButton extends StatefulWidget {
  final Future<void> Function() onAcknowledge;
  final String label;

  const SwipeToAcknowledgeButton({
    super.key,
    required this.onAcknowledge,
    this.label = 'เลื่อนเพื่อยอมรับว่าติดหนี้จริง',
  });

  @override
  State<SwipeToAcknowledgeButton> createState() => _SwipeToAcknowledgeButtonState();
}

class _SwipeToAcknowledgeButtonState extends State<SwipeToAcknowledgeButton> {
  double _dragPosition = 0.0;
  bool _isLoading = false;
  bool _isSuccess = false;

  final double _height = 46.0;
  final double _thumbWidth = 44.0;

  void _onDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_isLoading || _isSuccess) return;
    setState(() {
      _dragPosition += details.delta.dx;
      final maxDrag = maxWidth - _thumbWidth - 4;
      _dragPosition = _dragPosition.clamp(0.0, maxDrag);
    });
  }

  Future<void> _onDragEnd(DragEndDetails details, double maxWidth) async {
    if (_isLoading || _isSuccess) return;
    final maxDrag = maxWidth - _thumbWidth - 4;
    if (_dragPosition >= maxDrag * 0.7) {
      // Completed swipe
      HapticFeedback.mediumImpact();
      setState(() {
        _dragPosition = maxDrag;
        _isLoading = true;
      });

      try {
        await widget.onAcknowledge();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isSuccess = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _dragPosition = 0.0;
          });
        }
      }
    } else {
      // Revert back
      setState(() {
        _dragPosition = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxDrag = maxWidth - _thumbWidth - 4;
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: _isSuccess
                ? AppColors.success.withValues(alpha: 0.18)
                : (isDark ? AppColors.surfaceTile2 : const Color(0xFFF2F4F7)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isSuccess
                  ? AppColors.success
                  : (isDark ? Colors.white12 : AppColors.hairline),
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Filled track progress
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _isSuccess ? 1.0 : progress,
                child: Container(
                  height: _height,
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? AppColors.success
                        : AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              // Center Hint Text
              Center(
                child: AnimatedOpacity(
                  opacity: _isLoading || _isSuccess ? 1.0 : (1.0 - progress * 1.5).clamp(0.0, 1.0),
                  duration: const Duration(milliseconds: 150),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSuccess) ...[
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'ยอมรับหนี้แล้ว',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ] else if (_isLoading) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'กำลังบันทึก...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ] else ...[
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Sliding Thumb / Knob
              if (!_isSuccess)
                Positioned(
                  left: 2 + _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxWidth),
                    onHorizontalDragEnd: (details) => _onDragEnd(details, maxWidth),
                    child: Container(
                      width: _thumbWidth,
                      height: _height - 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
