import 'dart:convert';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/app_toast.dart';
import '../../payments/providers/payment_providers.dart';
import 'widgets/destructive_confirmation_sheet.dart';
import '../models/bill_models.dart';
import '../providers/bill_provider.dart';
import '../repositories/bill_repository.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  final String billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(billDetailProvider(widget.billId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text(
          'รายละเอียดบิล',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          billAsync.maybeWhen(
            data: (bill) {
              if (bill.status == 'cancelled') return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                tooltip: 'ยกเลิกบิล',
                onPressed: () => _handleCancelBill(context, bill),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: billAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 42,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'โหลดข้อมูลบิลไม่สำเร็จ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.inkMuted48),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(billDetailProvider(widget.billId)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('ลองใหม่'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (bill) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Hero Bill Overview Card
                Container(
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
                        SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Icon + Title + Status Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: ShapeDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: const SmoothRectangleBorder(
                                borderRadius: SmoothBorderRadius.all(
                                  SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.title ?? 'บิลค่าใช้จ่าย',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                  ),
                                ),
                                if (bill.description != null &&
                                    bill.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    bill.description!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _buildStatusBadge(bill.status),
                        ],
                      ),

                      const SizedBox(height: 18),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? Colors.white10 : AppColors.dividerSoft,
                      ),
                      const SizedBox(height: 16),

                      // 4-Column Accounting Grid with Soft Background Tile
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildAccountingColumn(
                              'ยอดรวมทั้งหมด',
                              '฿${bill.totalAmount.toStringAsFixed(2)}',
                              isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                            Container(width: 1, height: 28, color: isDark ? Colors.white10 : AppColors.dividerSoft),
                            _buildAccountingColumn(
                              'ชำระแล้ว',
                              '฿${bill.totalPaidAmount.toStringAsFixed(2)}',
                              AppColors.success,
                            ),
                            Container(width: 1, height: 28, color: isDark ? Colors.white10 : AppColors.dividerSoft),
                            _buildAccountingColumn(
                              'ยกหนี้ให้',
                              '฿${bill.totalWrittenOffAmount.toStringAsFixed(2)}',
                              isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                            Container(width: 1, height: 28, color: isDark ? Colors.white10 : AppColors.dividerSoft),
                            _buildAccountingColumn(
                              'คงค้าง',
                              '฿${bill.totalOutstandingAmount.toStringAsFixed(2)}',
                              AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (bill.receiptImageUrl != null &&
                    bill.receiptImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: ShapeDecoration(
                      color: isDark
                          ? AppColors.surfaceTile1
                          : AppColors.canvas,
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.receipt_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'รูปภาพใบเสร็จ / หลักฐาน (Receipt Photo)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: bill.receiptImageUrl!.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(
                                    bill.receiptImageUrl!.replaceFirst(
                                      RegExp(r'data:image/[^;]+;base64,'),
                                      '',
                                    ),
                                  ),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (ctx, _, __) => const Center(
                                    child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                  ),
                                )
                              : Image.network(
                                  bill.receiptImageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (ctx, _, __) => const Center(
                                    child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Section 2: Participants Portion Details Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'รายการลูกหนี้ / ผู้ร่วมหาร',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${bill.items.length} คน',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Participants List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bill.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final item = bill.items[idx];
                    final debtorName = item.debtor?.displayName ?? 'เพื่อน';
                    final isPaidLocked = item.isFullyPaid || item.isLocked;

                    return Container(
                      padding: const EdgeInsets.all(16),
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
                            SmoothRadius(
                              cornerRadius: 20,
                              cornerSmoothing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Debtor Header: Avatar + Name + ID + Status Pill
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                backgroundImage: item.debtor?.avatarUrl != null
                                    ? NetworkImage(item.debtor!.avatarUrl!)
                                    : null,
                                child: item.debtor?.avatarUrl == null
                                    ? Text(
                                        debtorName.isNotEmpty
                                            ? debtorName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      debtorName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'รหัส: ${item.debtor?.userCode ?? "-"}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildItemStatusBadge(item.status),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark ? Colors.white10 : AppColors.dividerSoft,
                          ),
                          const SizedBox(height: 12),

                          // Portions Row Details
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ยอดส่วนแบ่ง',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                                ),
                              ),
                              Text(
                                '฿${item.currentAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'จ่ายแล้ว',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                                ),
                              ),
                              Text(
                                '฿${item.amountPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          if (item.amountWrittenOff > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ยกหนี้ให้ (Write-off)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  ),
                                ),
                                Text(
                                  '฿${item.amountWrittenOff.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ยอดคงค้างสุทธิ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  '฿${item.outstandingAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Actions: Edit / Write-Off / Lock Indicator
                          if (isPaidLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ยอดชำระแล้วถูกล็อค (Paid amount locked)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _showEditAmountDialog(item),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    label: const Text(
                                      'แก้ไขยอด',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showWriteOffDialog(item),
                                    icon: const Icon(
                                      Icons.money_off_rounded,
                                      size: 15,
                                      color: AppColors.error,
                                    ),
                                    label: const Text(
                                      'ยกหนี้ให้',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      side: BorderSide(
                                        color: AppColors.error.withValues(alpha: 0.6),
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountingColumn(String title, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.inkMuted48),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    String text = 'ยังไม่ชำระ';
    Color bg = AppColors.primary.withValues(alpha: 0.12);
    Color fg = AppColors.primary;
    IconData icon = Icons.schedule_rounded;

    switch (status) {
      case 'fully_paid':
      case 'paid':
        text = 'ชำระครบแล้ว';
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'partially_paid':
        text = 'ชำระบางส่วน';
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'fully_written_off':
        text = 'ยกหนี้ครบทั้งหมด';
        bg = AppColors.inkMuted48.withValues(alpha: 0.12);
        fg = AppColors.inkMuted48;
        icon = Icons.money_off_rounded;
        break;
      case 'partially_written_off':
        text = 'ยกหนี้บางส่วน';
        bg = AppColors.inkMuted48.withValues(alpha: 0.12);
        fg = AppColors.inkMuted48;
        icon = Icons.money_off_rounded;
        break;
      case 'cancelled':
        text = 'ยกเลิกแล้ว';
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildItemStatusBadge(String status) {
    String text = 'ยังไม่ชำระ';
    Color bg = AppColors.primary.withValues(alpha: 0.12);
    Color fg = AppColors.primary;
    IconData icon = Icons.schedule_rounded;

    if (status == 'paid') {
      text = 'ชำระแล้ว';
      bg = AppColors.success.withValues(alpha: 0.12);
      fg = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (status == 'partially_paid') {
      text = 'ชำระบางส่วน';
      bg = AppColors.warning.withValues(alpha: 0.12);
      fg = AppColors.warning;
      icon = Icons.hourglass_top_rounded;
    } else if (status == 'written_off') {
      text = 'ยกหนี้ให้';
      bg = AppColors.inkMuted48.withValues(alpha: 0.12);
      fg = AppColors.inkMuted48;
      icon = Icons.money_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  void _showEditAmountDialog(BillItemParticipantModel item) {
    final controller = TextEditingController(
      text: item.currentAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('แก้ไขยอดของ ${item.debtor?.displayName ?? "ผู้ใช้"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เมื่อเปลี่ยนยอดของคนนี้ ระบบจะเฉลี่ยยอดที่เหลือให้เพื่อนคนอื่นที่ยังไม่จ่ายโดยอัตโนมัติ',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'ยอดใหม่ (บาท)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAmt = double.tryParse(controller.text.trim());
              if (newAmt == null || newAmt < 0) return;

              Navigator.pop(ctx);
              try {
                final repo = ref.read(billRepositoryProvider);
                await repo.editParticipantAmount(
                  billId: widget.billId,
                  participantId: item.id,
                  newAmount: newAmt,
                );
                ref.invalidate(billDetailProvider(widget.billId));
                ref.read(userReceivablesProvider.notifier).loadReceivables(showLoading: false);
                ref.invalidate(myBillsProvider);
                if (mounted) {
                  AppToast.success(context, 'อัปเดตยอดและเฉลี่ยหนี้เรียบร้อย');
                }
              } catch (e) {
                if (mounted) {
                  AppToast.error(context, 'แก้ไขไม่สำเร็จ: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5000),
              foregroundColor: Colors.white,
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showWriteOffDialog(BillItemParticipantModel item) {
    final controller = TextEditingController(
      text: item.outstandingAmount.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'ยกหนี้ให้ ${item.debtor?.displayName ?? "ผู้ใช้"} (Write-off)',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ยอดคงค้างปัจจุบัน: ฿${item.outstandingAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'การยกหนี้จะถูกบันทึกในประวัติการเงินอย่างโปร่งใส และไม่นับเป็นรายรับที่ชำระแล้ว',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'จำนวนเงินที่ต้องการยกหนี้ (บาท)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'เหตุผล (ถ้ามี)',
                  hintText: 'เช่น เลี้ยงเนื่องในวันเกิด',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final writeOffAmt = double.tryParse(controller.text.trim());
              if (writeOffAmt == null ||
                  writeOffAmt <= 0 ||
                  writeOffAmt > item.outstandingAmount) {
                AppToast.warning(context, 'ยอดเงินยกหนี้ไม่ถูกต้อง');
                return;
              }

              Navigator.pop(ctx);
              try {
                final repo = ref.read(billRepositoryProvider);
                await repo.writeOffDebt(
                  billId: widget.billId,
                  participants: [
                    {'participantId': item.id, 'amount': writeOffAmt},
                  ],
                  reason: reasonController.text.trim(),
                );
                ref.invalidate(billDetailProvider(widget.billId));
                ref.read(userReceivablesProvider.notifier).loadReceivables(showLoading: false);
                ref.invalidate(myBillsProvider);
                if (mounted) {
                  AppToast.success(context, 'ยกหนี้ ฿$writeOffAmt เรียบร้อย');
                }
              } catch (e) {
                if (mounted) {
                  AppToast.error(context, 'ยกหนี้ไม่สำเร็จ: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยันยกหนี้'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelBill(BuildContext parentContext, BillModel bill) async {
    final confirmed = await DestructiveConfirmationSheet.show(
      parentContext,
      title: 'ต้องการยกเลิกบิลนี้?',
      message:
          'การยกเลิกบิล "${bill.title ?? "บิลค่าใช้จ่าย"}" จะทำให้ยอดหนี้ที่เพื่อนค้างทั้งหมดในบิลนี้ถูกยกเลิก และจะหายออกจากหน้า "เพื่อนติดเรา" ทันที',
      confirmLabel: 'ยกเลิกบิลและหนี้ทั้งหมด',
      cancelLabel: 'กลับ',
      totalAmount: bill.totalOutstandingAmount > 0 ? bill.totalOutstandingAmount : bill.totalAmount,
      icon: Icons.cancel_outlined,
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(billRepositoryProvider);
        await repo.cancelBill(billId: bill.id);
        ref.invalidate(billDetailProvider(bill.id));
        ref.read(userReceivablesProvider.notifier).loadReceivables(showLoading: false);
        ref.invalidate(myBillsProvider);
        if (mounted) {
          AppToast.success(context, 'ยกเลิกบิลเรียบร้อยแล้ว หนี้ถูกลบออกจากระบบแล้ว');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, 'ยกเลิกบิลไม่สำเร็จ: $e');
        }
      }
    }
  }
}
