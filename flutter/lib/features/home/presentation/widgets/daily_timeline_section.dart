import 'dart:convert';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../bills/models/bill_models.dart';
import '../../../payments/models/payment_models.dart';
import '../../../payments/presentation/widgets/payment_detail_bottom_sheet.dart';

class DailyTimelineSection extends StatelessWidget {
  final DateTime selectedDate;
  final List<BillModel> bills;
  final List<DebtItemModel> debts;
  final VoidCallback onCreateBill;

  const DailyTimelineSection({
    super.key,
    required this.selectedDate,
    required this.bills,
    this.debts = const [],
    required this.onCreateBill,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const thaiFullMonths = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final formattedDate =
        '${selectedDate.day} ${thaiFullMonths[selectedDate.month - 1]} ${selectedDate.year + 543}';

    // Calculate metrics for selected date
    final totalExpense = bills.fold(0.0, (acc, b) => acc + b.totalAmount);
    final totalCollected = bills.fold(0.0, (acc, b) => acc + b.totalPaidAmount);
    final totalOutstanding = bills.fold(0.0, (acc, b) => acc + b.totalOutstandingAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รายการของวันที่ $formattedDate',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              if (bills.isNotEmpty)
                Text(
                  '${bills.length} รายการ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted48,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Daily Summary Pill / Mini Card
        if (bills.isNotEmpty || debts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
                shape: SmoothRectangleBorder(
                  side: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.hairline,
                  ),
                  borderRadius: const SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem(
                    label: 'ยอดรวมบิล',
                    amount: totalExpense,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    isDark: isDark,
                  ),
                  Container(
                    height: 22,
                    width: 1,
                    color: isDark ? Colors.white10 : AppColors.hairline,
                  ),
                  _buildMetricItem(
                    label: 'ได้รับแล้ว',
                    amount: totalCollected,
                    color: AppColors.success,
                    isDark: isDark,
                  ),
                  Container(
                    height: 22,
                    width: 1,
                    color: isDark ? Colors.white10 : AppColors.hairline,
                  ),
                  _buildMetricItem(
                    label: 'ยังค้างอยู่',
                    amount: totalOutstanding,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 10),

        // Content: Bills created & Debts owed to friends
        if (bills.isEmpty && debts.isEmpty)
          _buildEmptyDateState(context, isDark)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (debts.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF007AFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'หนี้ที่คุณต้องจ่ายให้เพื่อน (${debts.length} รายการ)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF5AC8FA) : const Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: debts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final debt = debts[index];
                      return _buildDebtItemTile(context, debt, isDark);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                if (bills.isNotEmpty) ...[
                  if (debts.isNotEmpty)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'บิลที่คุณสร้าง (${bills.length} รายการ)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  if (debts.isNotEmpty) const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return _buildBillItemTile(context, bill, isDark);
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDebtItemTile(BuildContext context, DebtItemModel debt, bool isDark) {
    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: const Color(0xFF007AFF).withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => PaymentDetailBottomSheet.show(context, debt),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _buildDebtLeadingAvatar(debt),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.billTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ต้องจ่ายให้ ${debt.creditor.displayName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '฿${debt.outstandingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'แตะเพื่อจ่าย',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
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

  Widget _buildDebtLeadingAvatar(DebtItemModel debt) {
    final avatarUrl = debt.creditor.avatarUrl;
    final receiptImg = debt.receiptImageUrl;
    final displayName = debt.creditor.displayName;

    // Helper to build creditor circular avatar
    Widget buildAvatarCircle({double size = 42, double borderWidth = 0}) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: borderWidth > 0
              ? Border.all(color: Colors.white, width: borderWidth)
              : null,
          boxShadow: borderWidth > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildInitialAvatar(displayName, size),
                )
              : _buildInitialAvatar(displayName, size),
        ),
      );
    }

    // If there is an evidence/receipt image: show receipt image thumbnail with creditor avatar at bottom-left
    if (receiptImg != null && receiptImg.isNotEmpty) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Receipt image thumbnail
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: receiptImg.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(
                          receiptImg.replaceFirst(
                            RegExp(r'data:image/[^;]+;base64,'),
                            '',
                          ),
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF007AFF), size: 22),
                        ),
                      )
                    : Image.network(
                        receiptImg,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF007AFF), size: 22),
                        ),
                      ),
              ),
            ),
            // Creditor Avatar at Bottom-Left
            Positioned(
              bottom: -3,
              left: -3,
              child: buildAvatarCircle(size: 22, borderWidth: 1.5),
            ),
          ],
        ),
      );
    }

    // Default: Creditor avatar
    return buildAvatarCircle(size: 42);
  }

  Widget _buildInitialAvatar(String name, double size) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : 'U';
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF007AFF).withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF007AFF),
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.inkMuted48,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '฿${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDateState(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.hairline,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_note_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ไม่มีรายการบิลในวันนี้',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'หากมีค่าใช้จ่ายเกิดขึ้น สามารถสร้างบิลเพื่อหารกับเพื่อนได้ทันที',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted48),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onCreateBill,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('สร้างบิลใหม่', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillItemTile(BuildContext context, BillModel bill, bool isDark) {
    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.hairline,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/bills/${bill.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 11, cornerSmoothing: 1.0),
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (bill.title != null && bill.title!.trim().isNotEmpty)
                            ? bill.title!
                            : 'บิลค่าใช้จ่าย',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${bill.items.length} ผู้ร่วมหาร • ${_formatStatus(bill.status)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getStatusColor(bill.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '฿${bill.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'paid':
      case 'fully_paid':
        return 'ชำระครบแล้ว';
      case 'partially_paid':
        return 'ชำระบางส่วน';
      case 'cancelled':
        return 'ยกเลิกแล้ว';
      default:
        return 'รอชำระ';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
      case 'fully_paid':
        return AppColors.success;
      case 'partially_paid':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.inkMuted48;
    }
  }
}
