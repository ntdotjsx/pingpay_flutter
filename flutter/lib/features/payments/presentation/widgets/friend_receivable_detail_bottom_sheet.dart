import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../models/payment_models.dart';
import '../../providers/payment_providers.dart';
import '../../services/debt_age_calculator.dart';

class FriendReceivableDetailBottomSheet extends ConsumerStatefulWidget {
  final ReceivableFriendModel friend;

  const FriendReceivableDetailBottomSheet({super.key, required this.friend});

  static Future<void> show(BuildContext context, ReceivableFriendModel friend) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FriendReceivableDetailBottomSheet(friend: friend),
    );
  }

  @override
  ConsumerState<FriendReceivableDetailBottomSheet> createState() =>
      _FriendReceivableDetailBottomSheetState();
}

class _FriendReceivableDetailBottomSheetState
    extends ConsumerState<FriendReceivableDetailBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friend = widget.friend;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.only(
            topLeft: SmoothRadius(cornerRadius: 28, cornerSmoothing: 1.0),
            topRight: SmoothRadius(cornerRadius: 28, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white24
                    : AppColors.inkMuted48.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _buildAvatar(isDark),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.debtor.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ติดเราทั้งหมด ฿${friend.totalOutstandingAmount.toStringAsFixed(2)} • ${friend.bills.length} รายการ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted48,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : AppColors.dividerSoft,
          ),

          // Bills List
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: friend.bills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = friend.bills[index];
                return _buildBillItemCard(context, item, isDark);
              },
            ),
          ),

          // Bottom Summary Bar
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceTile2
                  : AppColors.canvasParchment,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : AppColors.hairline,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ยอดรวมที่ติดเรา',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '฿${friend.totalOutstandingAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillItemCard(
    BuildContext context,
    ReceivableBillItemModel item,
    bool isDark,
  ) {
    final ageText = DebtAgeCalculator.formatDebtAgeThai(item.debtStartDate);
    final formattedDate = DebtAgeCalculator.formatThaiDate(item.debtStartDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile2 : AppColors.canvas,
        shape: SmoothRectangleBorder(
          side: BorderSide(color: isDark ? Colors.white10 : AppColors.hairline),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.billTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                item.isOutstanding
                    ? 'ติดเรา ฿${item.outstandingAmount.toStringAsFixed(2)}'
                    : (item.status == 'written_off'
                          ? 'ตัดหนี้แล้ว'
                          : 'ชำระแล้ว'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: item.isOutstanding
                      ? AppColors.primary
                      : (item.status == 'written_off'
                            ? AppColors.inkMuted48
                            : AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ยอดเดิม ฿${item.originalAmount.toStringAsFixed(2)} • จ่ายแล้ว ฿${item.amountPaid.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted48,
                ),
              ),
              Text(
                '$ageText ($formattedDate)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkMuted48,
                ),
              ),
            ],
          ),

          // Payment Progress Bar if partially paid
          if (item.isPartiallyPaid) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.paymentProgress,
                backgroundColor: isDark ? Colors.white10 : AppColors.hairline,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.success,
                ),
                minHeight: 5,
              ),
            ),
          ],

          // Actions: [ แก้ไขยอด ] & [ ยกเลิกหนี้ (Write-off) ]
          if (item.isOutstanding) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditAmountDialog(context, item),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('แก้ไขยอด', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : AppColors.hairline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showWriteOffDialog(context, item),
                    icon: const Icon(
                      Icons.money_off_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'ยกเลิกหนี้',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEditAmountDialog(BuildContext context, ReceivableBillItemModel item) {
    final controller = TextEditingController(
      text: item.currentAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('แก้ไขยอดหนี้ของ ${widget.friend.debtor.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'บิล: ${item.billTitle}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'เมื่อเปลี่ยนยอดของคนนี้ ระบบจะเฉลี่ยยอดที่เหลือให้เพื่อนคนอื่นที่ยังไม่จ่ายในบิลนี้โดยอัตโนมัติ',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted48),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              final success = await ref
                  .read(userReceivablesProvider.notifier)
                  .editParticipantAmount(
                    billId: item.billId,
                    participantId: item.id,
                    newAmount: newAmt,
                  );

              if (mounted) {
                if (success) {
                  AppToast.success(this.context, 'อัปเดตยอดหนี้เรียบร้อยแล้ว');
                  Navigator.pop(this.context); // Close bottom sheet to see refreshed list
                } else {
                  AppToast.error(this.context, 'ไม่สามารถแก้ไขยอดได้');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showWriteOffDialog(BuildContext context, ReceivableBillItemModel item) {
    final controller = TextEditingController(
      text: item.outstandingAmount.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('ยกเลิกหนี้ให้ ${widget.friend.debtor.displayName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'บิล: ${item.billTitle}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'ยอดคงค้างปัจจุบัน: ฿${item.outstandingAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              const Text(
                'การยกเลิกหนี้ (Write-off) จะลบยอดหนี้นี้ออกจาก "เพื่อนติดเรา" ทันที โดยบันทึกประวัติไว้อย่างถูกต้อง',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted48),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'จำนวนเงินที่ต้องการยกเลิกหนี้ (บาท)',
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
                  hintText: 'เช่น เลี้ยงเนื่องในโอกาสพิเศษ / ยกยอดให้',
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
                AppToast.warning(ctx, 'จำนวนเงินยกเลิกหนี้ไม่ถูกต้อง');
                return;
              }

              Navigator.pop(ctx);
              final success = await ref
                  .read(userReceivablesProvider.notifier)
                  .writeOffDebt(
                    billId: item.billId,
                    participantId: item.id,
                    amount: writeOffAmt,
                    reason: reasonController.text.trim(),
                  );

              if (mounted) {
                if (success) {
                  AppToast.success(
                    this.context,
                    'ยกเลิกหนี้ ฿${writeOffAmt.toStringAsFixed(2)} เรียบร้อยแล้ว',
                  );
                  Navigator.pop(this.context); // Close bottom sheet to see updated list
                } else {
                  AppToast.error(this.context, 'ไม่สามารถยกเลิกหนี้ได้');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ยืนยันยกเลิกหนี้'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    final debtor = widget.friend.debtor;
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      backgroundImage:
          (debtor.avatarUrl != null && debtor.avatarUrl!.trim().isNotEmpty)
          ? NetworkImage(debtor.avatarUrl!)
          : null,
      child: (debtor.avatarUrl == null || debtor.avatarUrl!.trim().isEmpty)
          ? Text(
              debtor.displayName.isNotEmpty
                  ? debtor.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}
