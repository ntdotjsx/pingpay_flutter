import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme.dart';
import '../../../bills/models/bill_models.dart';

class MonthlyBillTile extends StatelessWidget {
  final BillModel bill;

  const MonthlyBillTile({
    super.key,
    required this.bill,
  });

  static const List<String> _thaiMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  String _formatDate(DateTime dt) {
    final day = dt.day;
    final month = _thaiMonths[dt.month - 1];
    final year = dt.year + 543;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat('#,##0.00', 'th');
    final dateStr = bill.createdAt != null ? _formatDate(bill.createdAt!) : '';

    return GestureDetector(
      onTap: () => context.push('/bills/${bill.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
            ),
          ),
        ),
        child: Row(
          children: [
            // Bill Icon Squircle
            Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(
                color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.2 : 0.1),
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                  ),
                ),
              ),
              child: const Icon(
                Icons.receipt_rounded,
                color: Color(0xFFFF5000),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Title & Date Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title?.trim().isNotEmpty == true ? bill.title! : 'บิลค่าใช้จ่าย',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                      if (bill.items.isNotEmpty) ...[
                        Text(
                          ' • ${bill.items.length} คน',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount & Status Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '฿${currencyFormatter.format(bill.totalAmount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                _buildMiniStatusBadge(bill, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatusBadge(BillModel bill, bool isDark) {
    if (bill.isFullyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'ครบแล้ว',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF10B981),
          ),
        ),
      );
    }

    if (bill.totalPaidAmount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'จ่ายบางส่วน',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2563EB),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'รอเก็บเงิน',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFF9500),
        ),
      ),
    );
  }
}
