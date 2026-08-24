import 'dart:convert';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../models/payment_models.dart';
import '../../providers/payment_providers.dart';
import '../../services/debt_age_calculator.dart';
import '../../../friends/providers/friend_nickname_provider.dart';

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
  void _showFullReceiptDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(
                          imageUrl.replaceFirst(
                            RegExp(r'data:image/[^;]+;base64,'),
                            '',
                          ),
                        ),
                        fit: BoxFit.contain,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friend = widget.friend;
    final nicknamesMap = ref.watch(friendNicknameProvider);
    final nickname = nicknamesMap[friend.debtor.id] ?? nicknamesMap[friend.debtor.userCode];
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final effectiveName = hasNickname ? nickname : friend.debtor.displayName;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.only(
            topLeft: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
            topRight: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _buildAvatar(isDark, effectiveName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              effectiveName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasNickname) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${friend.debtor.displayName})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ติดเราทั้งหมด ฿${friend.totalOutstandingAmount.toStringAsFixed(2)} • ${friend.bills.length} รายการ',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),

          // Bills List
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              itemCount: friend.bills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = friend.bills[index];
                return _buildBillItemCard(context, item, effectiveName, isDark);
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
                  : const Color(0xFFF9FAFB),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ยอดรวมที่ติดเรา',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                Text(
                  '฿${friend.totalOutstandingAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF5000),
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
    String effectiveName,
    bool isDark,
  ) {
    final ageText = DebtAgeCalculator.formatDebtAgeThai(item.debtStartDate);
    final formattedDate = DebtAgeCalculator.formatThaiDate(item.debtStartDate);

    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tappable Header to Open Full Bill Details
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              onTap: () {
                Navigator.pop(context); // Close bottom sheet
                context.push('/bills/${item.billId}');
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.billTitle,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'ยอดเดิม ฿${item.originalAmount.toStringAsFixed(2)} • จ่ายแล้ว ฿${item.amountPaid.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.isOutstanding
                                  ? 'ติดเรา ฿${item.outstandingAmount.toStringAsFixed(2)}'
                                  : (item.status == 'written_off'
                                        ? 'ตัดหนี้แล้ว'
                                        : 'ชำระแล้ว'),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: item.isOutstanding
                                    ? const Color(0xFFFF5000)
                                    : (item.status == 'written_off'
                                          ? (isDark ? AppColors.bodyMuted : AppColors.inkMuted48)
                                          : const Color(0xFF34C759)),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$ageText ($formattedDate)',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Payment Progress Bar if partially paid
                    if (item.isPartiallyPaid) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.paymentProgress,
                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF34C759),
                          ),
                          minHeight: 4.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 2. Receipt / Evidence Image Thumbnail if available
          if (item.receiptImageUrl != null && item.receiptImageUrl!.isNotEmpty) ...[
            Divider(
              height: 1,
              thickness: 0.6,
              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            size: 14,
                            color: Color(0xFFFF5000),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'หลักฐานบิล / รูปใบเสร็จ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showFullReceiptDialog(context, item.receiptImageUrl!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'ดูรูปเต็ม',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF5000),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: () => _showFullReceiptDialog(context, item.receiptImageUrl!),
                    child: Container(
                      height: 72,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                          width: 0.8,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.receiptImageUrl!.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(
                                  item.receiptImageUrl!.replaceFirst(
                                    RegExp(r'data:image/[^;]+;base64,'),
                                    '',
                                  ),
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, _, __) => const Center(
                                  child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
                                ),
                              )
                            : Image.network(
                                item.receiptImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, _, __) => const Center(
                                  child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Action Buttons Row: [ ดูบิลเต็ม ] [ แก้ไขยอด ] [ ยกเลิกหนี้ ]
          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/bills/${item.billId}');
                    },
                    icon: const Icon(Icons.receipt_rounded, size: 13),
                    label: const Text('ดูบิลเต็ม', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      foregroundColor: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      side: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (item.isOutstanding && item.amountPaid <= 0 && !item.isLocked) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditAmountDialog(context, item, effectiveName),
                      icon: const Icon(Icons.edit_outlined, size: 13),
                      label: const Text('แก้ไขยอด', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        foregroundColor: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showWriteOffDialog(context, item, effectiveName),
                      icon: const Icon(
                        Icons.money_off_rounded,
                        size: 13,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        'ยกเลิกหนี้',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAmountDialog(
    BuildContext context,
    ReceivableBillItemModel item,
    String effectiveName,
  ) {
    if (item.amountPaid > 0) {
      AppToast.warning(context, 'มีการชำระเงินงวดแรกเข้ามาแล้ว จึงไม่สามารถแก้ไขยอดได้');
      return;
    }

    final controller = TextEditingController(
      text: item.currentAmount.toStringAsFixed(2),
    );

    final maxAllowed = (item.originalAmount > 0) ? item.originalAmount : item.currentAmount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('แก้ไขยอดหนี้ของ $effectiveName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'บิล: ${item.billTitle}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'ยอดตั้งต้น: ฿${maxAllowed.toStringAsFixed(2)} • ยอดปัจจุบัน: ฿${item.currentAmount.toStringAsFixed(2)}\n* สามารถปรับลดยอด หรือปรับกลับขึ้นได้ไม่เกินยอดตั้งต้น (฿${maxAllowed.toStringAsFixed(2)})',
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted48, height: 1.35),
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
              if (newAmt == null || newAmt < 0) {
                AppToast.warning(ctx, 'กรุณาระบุจำนวนเงินที่ถูกต้อง (ตั้งแต่ 0 ขึ้นไป)');
                return;
              }
              if (newAmt > maxAllowed) {
                AppToast.warning(
                  ctx,
                  'ไม่สามารถปรับยอดเงินสูงกว่ายอดตั้งต้น (฿${maxAllowed.toStringAsFixed(2)}) ได้',
                );
                return;
              }

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

  void _showWriteOffDialog(
    BuildContext context,
    ReceivableBillItemModel item,
    String effectiveName,
  ) {
    final controller = TextEditingController(
      text: item.outstandingAmount.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('ยกเลิกหนี้ให้ $effectiveName'),
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

  Widget _buildAvatar(bool isDark, String effectiveName) {
    final debtor = widget.friend.debtor;
    return Container(
      width: 44,
      height: 44,
      decoration: ShapeDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.6),
          ),
        ),
      ),
      child: ClipSmoothRect(
        radius: const SmoothBorderRadius.all(
          SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.6),
        ),
        child: (debtor.avatarUrl != null && debtor.avatarUrl!.trim().isNotEmpty)
            ? Image.network(
                debtor.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    effectiveName.isNotEmpty
                        ? effectiveName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  effectiveName.isNotEmpty
                      ? effectiveName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}
