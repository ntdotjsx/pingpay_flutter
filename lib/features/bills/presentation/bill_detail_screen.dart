import 'dart:convert';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../payments/providers/payment_providers.dart';
import 'widgets/destructive_confirmation_sheet.dart';
import '../models/bill_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../friends/providers/friend_nickname_provider.dart';
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
      backgroundColor: isDark ? AppColors.surfaceBlack : Colors.white,
      body: billAsync.when(
        loading: () => const BillDetailSkeleton(),
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
                    backgroundColor: const Color(0xFFFF5000),
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
          final currentUserId = ref.read(authStateProvider).user?.id;
          final isOwner = currentUserId == bill.ownerId;
          final dateStr = bill.createdAt != null
              ? DateFormat('dd MMM yyyy • HH:mm', 'th').format(bill.createdAt!)
              : '';

          return Column(
            children: [
              // 1. Signature PingPay Executive Gradient Header
              Container(
                width: double.infinity,
                decoration: const ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF5000),
                      Color(0xFFFF6A00),
                      Color(0xFFFF8500),
                    ],
                  ),
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.only(
                      bottomLeft: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
                      bottomRight: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: ShapeDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: const SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius.all(
                                    SmoothRadius(cornerRadius: 19, cornerSmoothing: 1.0),
                                  ),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: () => context.pop(),
                              ),
                            ),
                            const Text(
                              'รายละเอียดบิล',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (isOwner && bill.status != 'cancelled')
                              Container(
                                width: 38,
                                height: 38,
                                decoration: ShapeDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: const SmoothRectangleBorder(
                                    borderRadius: SmoothBorderRadius.all(
                                      SmoothRadius(cornerRadius: 19, cornerSmoothing: 1.0),
                                    ),
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  tooltip: 'ยกเลิกบิล',
                                  onPressed: () => _handleCancelBill(context, bill),
                                ),
                              )
                            else
                              const SizedBox(width: 38),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            _buildStatusBadge(bill.status, inHeader: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Middle Scrollable Area (Clean Inset-Grouped Lists)
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Group 1: Bill Overview & Accounting Grid (Clean Inset Card)
                      Container(
                        decoration: ShapeDecoration(
                          color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
                          shape: SmoothRectangleBorder(
                            side: BorderSide(
                              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                              width: 0.8,
                            ),
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Row 1: Bill Name & Thumbnail
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: (bill.receiptImageUrl != null && bill.receiptImageUrl!.isNotEmpty)
                                        ? () => _showFullReceiptDialog(context, bill.receiptImageUrl!)
                                        : null,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const ShapeDecoration(
                                        color: Color(0x1FFF5000),
                                        shape: SmoothRectangleBorder(
                                          borderRadius: SmoothBorderRadius.all(
                                            SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.8),
                                          ),
                                        ),
                                      ),
                                      child: ClipSmoothRect(
                                        radius: const SmoothBorderRadius.all(
                                          SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.8),
                                        ),
                                        child: (bill.receiptImageUrl != null && bill.receiptImageUrl!.isNotEmpty)
                                            ? (bill.receiptImageUrl!.startsWith('data:image')
                                                ? Image.memory(
                                                    base64Decode(
                                                      bill.receiptImageUrl!.replaceFirst(
                                                        RegExp(r'data:image/[^;]+;base64,'),
                                                        '',
                                                      ),
                                                    ),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(
                                                      Icons.receipt_long_rounded,
                                                      color: Color(0xFFFF5000),
                                                      size: 20,
                                                    ),
                                                  )
                                                : Image.network(
                                                    bill.receiptImageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(
                                                      Icons.receipt_long_rounded,
                                                      color: Color(0xFFFF5000),
                                                      size: 20,
                                                    ),
                                                  ))
                                            : const Icon(
                                                Icons.receipt_long_rounded,
                                                color: Color(0xFFFF5000),
                                                size: 20,
                                              ),
                                      ),
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
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                          ),
                                        ),
                                        if (bill.description != null && bill.description!.isNotEmpty) ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            bill.description!,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '฿${bill.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF5000),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Divider(
                              height: 1,
                              thickness: 0.6,
                              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                            ),

                            // Row 2: Multi-Metric Accounting Inset Grid
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildAccountingColumn(
                                    'ยอดเต็มบิล',
                                    '฿${bill.totalAmount.toStringAsFixed(2)}',
                                    isDark ? AppColors.bodyOnDark : AppColors.ink,
                                  ),
                                  if (bill.hasMyShare) ...[
                                    Container(width: 0.6, height: 26, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                    _buildAccountingColumn(
                                      'ส่วนของฉัน',
                                      '฿${bill.myShare.toStringAsFixed(2)}',
                                      const Color(0xFFFF5000),
                                    ),
                                  ],
                                  Container(width: 0.6, height: 26, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                  _buildAccountingColumn(
                                    'ชำระแล้ว',
                                    '฿${bill.totalPaidAmount.toStringAsFixed(2)}',
                                    const Color(0xFF34C759),
                                  ),
                                  if (bill.totalWrittenOffAmount > 0) ...[
                                    Container(width: 0.6, height: 26, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                    _buildAccountingColumn(
                                      'ยกหนี้ให้',
                                      '฿${bill.totalWrittenOffAmount.toStringAsFixed(2)}',
                                      isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                    ),
                                  ],
                                  Container(width: 0.6, height: 26, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                  _buildAccountingColumn(
                                    'คงค้างที่ต้องเก็บ',
                                    '฿${bill.totalOutstandingAmount.toStringAsFixed(2)}',
                                    bill.totalOutstandingAmount > 0 ? const Color(0xFFFF5000) : const Color(0xFF34C759),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Group 2: Receipt Image (Clean Inset Card)
                      if (bill.receiptImageUrl != null && bill.receiptImageUrl!.isNotEmpty) ...[
                        Container(
                          decoration: ShapeDecoration(
                            color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
                            shape: SmoothRectangleBorder(
                              side: BorderSide(
                                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                                width: 0.8,
                              ),
                              borderRadius: const SmoothBorderRadius.all(
                                SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const ShapeDecoration(
                                      color: Color(0x1FFF5000),
                                      shape: SmoothRectangleBorder(
                                        borderRadius: SmoothBorderRadius.all(
                                          SmoothRadius(cornerRadius: 9, cornerSmoothing: 0.8),
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_rounded,
                                      color: Color(0xFFFF5000),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'รูปภาพใบเสร็จ / หลักฐาน',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                          ),
                                        ),
                                        Text(
                                          'แตะที่รูปเพื่อดูภาพขนาดเต็ม',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showFullReceiptDialog(context, bill.receiptImageUrl!),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'ดูรูปเต็ม',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFFF5000),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _showFullReceiptDialog(context, bill.receiptImageUrl!),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    width: double.infinity,
                                    color: Colors.black12,
                                    child: bill.receiptImageUrl!.startsWith('data:image')
                                        ? Image.memory(
                                            base64Decode(
                                              bill.receiptImageUrl!.replaceFirst(
                                                RegExp(r'data:image/[^;]+;base64,'),
                                                '',
                                              ),
                                            ),
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, _, __) => const Center(
                                              child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                                            ),
                                          )
                                        : Image.network(
                                            bill.receiptImageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, _, __) => const Center(
                                              child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Group 3: Participants List (Unified Inset-Grouped List)
                      Container(
                        decoration: ShapeDecoration(
                          color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
                          shape: SmoothRectangleBorder(
                            side: BorderSide(
                              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                              width: 0.8,
                            ),
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: const ShapeDecoration(
                                          color: Color(0x1FFF5000),
                                          shape: SmoothRectangleBorder(
                                            borderRadius: SmoothBorderRadius.all(
                                              SmoothRadius(cornerRadius: 7, cornerSmoothing: 0.8),
                                            ),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.group_rounded,
                                          color: Color(0xFFFF5000),
                                          size: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ผู้ร่วมหารบิล',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${bill.items.length} คน',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF5000),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Divider(
                              height: 1,
                              thickness: 0.6,
                              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                            ),

                            // List of participants inside the card
                            ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: bill.items.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                thickness: 0.6,
                                indent: 52,
                                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                              ),
                              itemBuilder: (ctx, idx) {
                                final item = bill.items[idx];
                                final nicknamesMap = ref.watch(friendNicknameProvider);
                                final nick = item.debtor != null
                                    ? (nicknamesMap[item.debtor!.id] ?? nicknamesMap[item.debtor!.userCode])
                                    : null;
                                final hasNick = nick != null && nick.trim().isNotEmpty;
                                final debtorName = hasNick ? nick : (item.debtor?.displayName ?? 'เพื่อน');
                                final avatarUrl = item.debtor?.avatarUrl;
                                final hasAnyPayment = bill.items.any((i) => i.amountPaid > 0) || bill.totalPaidAmount > 0;
                                final isItemPaid = item.amountPaid > 0 || item.isFullyPaid || item.isLocked;
                                final isPaidLocked = hasAnyPayment || isItemPaid;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Real Debtor Avatar
                                      _buildUserAvatar(
                                        avatarUrl: avatarUrl,
                                        displayName: debtorName,
                                        isDark: isDark,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    debtorName,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13.5,
                                                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (hasNick && item.debtor?.displayName != null) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '(${item.debtor!.displayName})',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(width: 6),
                                                _buildItemStatusBadge(item),
                                              ],
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              'ยอด ฿${item.currentAmount.toStringAsFixed(2)} • จ่ายแล้ว ฿${item.amountPaid.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                              ),
                                            ),
                                            // Action buttons inline
                                            if (isOwner && !isPaidLocked && item.outstandingAmount > 0) ...[
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _showEditAmountDialog(item),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.edit_outlined, size: 10.5, color: Color(0xFFFF5000)),
                                                          SizedBox(width: 3),
                                                          Text(
                                                            'แก้ไขยอด',
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.w700,
                                                              color: Color(0xFFFF5000),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () => _showWriteOffDialog(item),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.error.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.money_off_rounded, size: 10.5, color: AppColors.error),
                                                          SizedBox(width: 3),
                                                          Text(
                                                            'ยกหนี้ให้',
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.w700,
                                                              color: AppColors.error,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '฿${item.outstandingAmount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: item.outstandingAmount > 0
                                                  ? const Color(0xFFFF5000)
                                                  : const Color(0xFF34C759),
                                            ),
                                          ),
                                          Text(
                                            item.outstandingAmount > 0 ? 'คงค้าง' : 'ครบแล้ว',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
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
                      ),

                      // Group 4: Audit & Activity Logs (if editLogs present)
                      if (bill.editLogs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          decoration: ShapeDecoration(
                            color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
                            shape: SmoothRectangleBorder(
                              side: BorderSide(
                                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                                width: 0.8,
                              ),
                              borderRadius: const SmoothBorderRadius.all(
                                SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                                child: Row(
                                  children: [
                                    const Icon(Icons.history_rounded, size: 15, color: Color(0xFFFF5000)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ประวัติการแก้ไขและยกหนี้',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.6,
                                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                              ),
                              ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: bill.editLogs.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 0.6,
                                  indent: 48,
                                  color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                                ),
                                itemBuilder: (ctx, idx) {
                                  final log = bill.editLogs[idx];
                                  final isWriteOff = log.action == 'debt_written_off' || log.action == 'write_off';
                                  final isCancel = log.action == 'bill_cancelled';
                                  final actionLabel = isWriteOff
                                      ? 'ยกหนี้ให้'
                                      : (isCancel ? 'ยกเลิกบิล' : 'แก้ไขข้อมูลบิล');
                                  final logColor = isCancel
                                      ? AppColors.error
                                      : (isWriteOff ? const Color(0xFFFF9500) : const Color(0xFFFF5000));
                                  final performerName = log.performedBy?.displayName ?? 'เจ้าของบิล';

                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4.5),
                                          decoration: BoxDecoration(
                                            color: logColor.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isCancel
                                                ? Icons.cancel_rounded
                                                : (isWriteOff ? Icons.money_off_rounded : Icons.edit_note_rounded),
                                            size: 11,
                                            color: logColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    actionLabel,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                                    ),
                                                  ),
                                                  if (log.createdAt != null)
                                                    Text(
                                                      DateFormat('dd/MM/yy HH:mm').format(log.createdAt!),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors.inkMuted48,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Text(
                                                'ดำเนินการโดย $performerName',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                                ),
                                              ),
                                              if (log.note != null && log.note!.trim().isNotEmpty)
                                                Text(
                                                  'เหตุผล: ${log.note!.trim()}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: Color(0xFFFF5000),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserAvatar({
    required String? avatarUrl,
    required String displayName,
    required bool isDark,
  }) {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'U';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF5000).withValues(alpha: 0.15),
        border: Border.all(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          width: 1.2,
        ),
      ),
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5000),
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5000),
                    fontSize: 12,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAccountingColumn(String title, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted48,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, {bool inHeader = false}) {
    String text = 'ยังไม่ชำระ';
    Color bg = inHeader ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFFF5000).withValues(alpha: 0.12);
    Color fg = inHeader ? Colors.white : const Color(0xFFFF5000);
    IconData icon = Icons.schedule_rounded;

    switch (status) {
      case 'fully_paid':
      case 'paid':
        text = 'ชำระครบแล้ว';
        bg = inHeader ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF34C759).withValues(alpha: 0.12);
        fg = inHeader ? Colors.white : const Color(0xFF34C759);
        icon = Icons.check_circle_rounded;
        break;
      case 'partially_paid':
        text = 'ชำระบางส่วน';
        bg = inHeader ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFFF9500).withValues(alpha: 0.12);
        fg = inHeader ? Colors.white : const Color(0xFFFF9500);
        icon = Icons.hourglass_top_rounded;
        break;
      case 'fully_written_off':
        text = 'ยกหนี้ครบ';
        bg = inHeader ? Colors.white.withValues(alpha: 0.22) : AppColors.inkMuted48.withValues(alpha: 0.12);
        fg = inHeader ? Colors.white : AppColors.inkMuted48;
        icon = Icons.money_off_rounded;
        break;
      case 'cancelled':
        text = 'ยกเลิกแล้ว';
        bg = inHeader ? Colors.white.withValues(alpha: 0.22) : AppColors.error.withValues(alpha: 0.12);
        fg = inHeader ? Colors.white : AppColors.error;
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: inHeader ? Border.all(color: Colors.white.withValues(alpha: 0.35)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemStatusBadge(BillItemParticipantModel item) {
    String text = 'ยังไม่ชำระ';
    Color bg = const Color(0xFFFF5000).withValues(alpha: 0.12);
    Color fg = const Color(0xFFFF5000);

    if (item.status == 'paid') {
      text = 'ชำระแล้ว';
      bg = const Color(0xFF34C759).withValues(alpha: 0.12);
      fg = const Color(0xFF34C759);
    } else if (item.status == 'partially_paid') {
      text = 'ชำระบางส่วน';
      bg = const Color(0xFFFF9500).withValues(alpha: 0.12);
      fg = const Color(0xFFFF9500);
    } else if (item.status == 'written_off') {
      text = 'ยกหนี้ให้';
      bg = AppColors.inkMuted48.withValues(alpha: 0.12);
      fg = AppColors.inkMuted48;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _showEditAmountDialog(BillItemParticipantModel item) {
    final nicknamesMap = ref.read(friendNicknameProvider);
    final nick = item.debtor != null
        ? (nicknamesMap[item.debtor!.id] ?? nicknamesMap[item.debtor!.userCode])
        : null;
    if (item.amountPaid > 0) {
      AppToast.warning(context, 'มีการชำระเงินงวดแรกเข้ามาแล้ว จึงไม่สามารถแก้ไขยอดได้');
      return;
    }

    final effectiveDebtorName = (nick != null && nick.trim().isNotEmpty)
        ? nick
        : (item.debtor?.displayName ?? 'ผู้ใช้');

    final controller = TextEditingController(
      text: item.currentAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('แก้ไขยอดของ $effectiveDebtorName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ยอดเดิม: ฿${item.currentAmount.toStringAsFixed(2)}\n* ระบบอนุญาตเฉพาะการปรับลดยอดเงิน (ห้ามปรับสูงกว่าเดิม) และจะเฉลี่ยส่วนต่างให้อัตโนมัติ',
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
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
              if (newAmt == null || newAmt < 0) {
                AppToast.warning(ctx, 'กรุณาระบุจำนวนเงินที่ถูกต้อง (ตั้งแต่ 0 ขึ้นไป)');
                return;
              }
              if (newAmt > item.currentAmount) {
                AppToast.warning(
                  ctx,
                  'ไม่สามารถปรับยอดเงินสูงกว่ายอดเดิม (฿${item.currentAmount.toStringAsFixed(2)}) ได้',
                );
                return;
              }

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
                ref.read(userDebtsProvider.notifier).loadDebts(showLoading: false);
                ref.invalidate(myBillsProvider);

                if (mounted) {
                  AppToast.success(
                    context,
                    'อัปเดตยอดและเฉลี่ยหนี้เรียบร้อย',
                  );
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
    final nicknamesMap = ref.read(friendNicknameProvider);
    final nick = item.debtor != null
        ? (nicknamesMap[item.debtor!.id] ?? nicknamesMap[item.debtor!.userCode])
        : null;
    final effectiveDebtorName = (nick != null && nick.trim().isNotEmpty)
        ? nick
        : (item.debtor?.displayName ?? 'ผู้ใช้');

    final controller = TextEditingController(
      text: item.outstandingAmount.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'ยกหนี้ให้ $effectiveDebtorName',
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
}
