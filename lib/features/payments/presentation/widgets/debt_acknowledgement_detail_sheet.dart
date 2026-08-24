import 'dart:convert';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bills/providers/bill_provider.dart';
import '../../../friends/providers/friend_nickname_provider.dart';
import '../../models/payment_models.dart';
import '../../providers/payment_providers.dart';
import '../../services/debt_age_calculator.dart';
import 'debt_card.dart';

class DebtAcknowledgementDetailSheet extends ConsumerWidget {
  final DebtItemModel debt;

  const DebtAcknowledgementDetailSheet({super.key, required this.debt});

  static Future<void> show(BuildContext context, DebtItemModel debt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DebtAcknowledgementDetailSheet(debt: debt),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DebtAgeCalculator.formatThaiDate(debt.debtStartDate);
    final debtAgeText = DebtAgeCalculator.formatDebtAgeThai(debt.debtStartDate);
    final billDetailAsync = ref.watch(billDetailProvider(debt.billId));
    final nicknamesMap = ref.watch(friendNicknameProvider);

    final creditorNick = nicknamesMap[debt.creditor.id] ?? nicknamesMap[debt.creditor.userCode];
    final hasCreditorNick = creditorNick != null && creditorNick.trim().isNotEmpty;
    final effectiveCreditorName = hasCreditorNick ? creditorNick : debt.creditor.displayName;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Title with Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFFF9500),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตรวจสอบรายละเอียดหนี้',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'กรุณาตรวจสอบความถูกต้องก่อนกวาดนิ้วยอมรับ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : AppColors.hairline.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: isDark ? Colors.white10 : AppColors.hairline),

            // Scrollable Content Area: Full Bill & Debt Details
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Creditor Info Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: ShapeDecoration(
                        color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                        shape: SmoothRectangleBorder(
                          borderRadius: const SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.white10 : AppColors.hairline,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
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
                              child: debt.creditor.avatarUrl != null && debt.creditor.avatarUrl!.isNotEmpty
                                  ? Image.network(
                                      debt.creditor.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          effectiveCreditorName.isNotEmpty
                                              ? effectiveCreditorName[0].toUpperCase()
                                              : 'U',
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
                                        effectiveCreditorName.isNotEmpty
                                            ? effectiveCreditorName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
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
                                  'เจ้าของบิล (ผู้บันทึกหนี้)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        effectiveCreditorName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                  ],
                                ),
                                if (debt.creditor.userCode.isNotEmpty)
                                  Text(
                                    'รหัสผู้ใช้: ${debt.creditor.userCode}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bill Breakdown Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: ShapeDecoration(
                        color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                        shape: SmoothRectangleBorder(
                          borderRadius: const SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.white10 : AppColors.hairline,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt.billTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'บันทึกเมื่อ $formattedDate ($debtAgeText)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: isDark ? Colors.white10 : AppColors.hairline),
                          const SizedBox(height: 14),

                          // Accounting rows
                          _buildDetailRow(
                            'ยอดส่วนแบ่งที่คุณต้องรับผิดชอบ:',
                            '฿${debt.outstandingAmount.toStringAsFixed(2)}',
                            isDark,
                            isHighlight: true,
                          ),

                          if (debt.amountWrittenOff > 0) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              '💡 ยอดที่ถูกหักล้างหนี้เดิมไปแล้ว:',
                              '-฿${debt.amountWrittenOff.toStringAsFixed(2)}',
                              isDark,
                              valueColor: AppColors.success,
                            ),
                            if (debt.originalAmount > debt.outstandingAmount) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'ยอดส่วนแบ่งเดิมก่อนหักล้าง:',
                                '฿${debt.originalAmount.toStringAsFixed(2)}',
                                isDark,
                              ),
                            ],
                          ],

                          billDetailAsync.maybeWhen(
                            data: (bill) {
                              final rawBreakdown = bill.itemsBreakdown;
                              List<dynamic> parsedItems = [];
                              if (rawBreakdown != null) {
                                if (rawBreakdown is List) {
                                  parsedItems = rawBreakdown;
                                } else if (rawBreakdown is Map && rawBreakdown['items'] is List) {
                                  parsedItems = rawBreakdown['items'] as List;
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    'ยอดรวมทั้งบิล:',
                                    '฿${bill.totalAmount.toStringAsFixed(2)}',
                                    isDark,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    'จำนวนผู้ร่วมหารทั้งหมด:',
                                    '${bill.items.length} คน',
                                    isDark,
                                  ),

                                  // ── Detailed Menu Items Breakdown if available ──
                                  if (parsedItems.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Divider(height: 1, color: isDark ? Colors.white10 : AppColors.hairline),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.restaurant_menu_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'รายการค่าใช้จ่ายในบิล (${parsedItems.length} รายการ)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...parsedItems.map((item) {
                                      final name = item['name'] ?? item['title'] ?? 'รายการอาหาร';
                                      final qty = item['quantity'] ?? item['qty'] ?? 1;
                                      final price = double.tryParse(item['price']?.toString() ?? item['amount']?.toString() ?? '0') ?? 0.0;
                                      final totalItemPrice = price * (qty is num ? qty.toDouble() : 1.0);

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '$name x$qty',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '฿${totalItemPrice.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  // ── Other Participants List Breakdown ──
                                  if (bill.items.length > 1) ...[
                                    const SizedBox(height: 10),
                                    Divider(height: 1, color: isDark ? Colors.white10 : AppColors.hairline),
                                    const SizedBox(height: 10),
                                    Text(
                                      'รายชื่อผู้ร่วมหารในบิลนี้',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...bill.items.map((p) {
                                      final pNick = p.debtor != null
                                          ? (nicknamesMap[p.debtor!.id] ?? nicknamesMap[p.debtor!.userCode])
                                          : null;
                                      final pName = (pNick != null && pNick.trim().isNotEmpty)
                                          ? pNick
                                          : (p.debtor?.displayName ?? 'เพื่อน');
                                      final isMe = p.debtorId == debt.debtorId;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              isMe ? '$pName (คุณ)' : pName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                                color: isMe ? AppColors.primary : (isDark ? AppColors.bodyMuted : AppColors.inkMuted80),
                                              ),
                                            ),
                                            Text(
                                              '฿${p.currentAmount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                                color: isMe ? AppColors.primary : (isDark ? AppColors.bodyMuted : AppColors.inkMuted80),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    // Offset Notice Box if debt was partially or fully offset
                    if (debt.amountWrittenOff > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: ShapeDecoration(
                          color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1),
                          shape: SmoothRectangleBorder(
                            side: BorderSide(
                              color: AppColors.success.withValues(alpha: 0.35),
                            ),
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sync_alt_rounded, color: AppColors.success, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'หมายเหตุ: มีการหักล้างหนี้เดิม (Debt Offset)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'บิลนี้ถูกหักล้างกับหนี้เดิมที่คุณเคยค้างกับ $effectiveCreditorName ไปแล้ว ฿${debt.amountWrittenOff.toStringAsFixed(2)} ยอดที่เหลือจ่ายจริงคือ ฿${debt.outstandingAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Receipt Image (if attached)
                    if (debt.receiptImageUrl != null && debt.receiptImageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'รูปภาพใบเสร็จ / หลักฐานจากเพื่อน',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: debt.receiptImageUrl!.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(
                                  debt.receiptImageUrl!.replaceFirst(
                                    RegExp(r'data:image/[^;]+;base64,'),
                                    '',
                                  ),
                                ),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 160,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                ),
                              )
                            : Image.network(
                                debt.receiptImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 160,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                ),
                              ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Information Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFFFF9500), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'เมื่อคุณปัดขวาด้านล่าง ยอดหนี้นี้จะถูกบันทึกเป็นหนี้อย่างเป็นทางการ และแสดงในหน้าการเงินของคุณ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFF9500),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Swipe Action
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.hairline,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SwipeToAcknowledgeButton(
                label: 'ปัดขวาเพื่อยอมรับว่าติดหนี้จริง',
                onAcknowledge: () async {
                  await ref.read(userDebtsProvider.notifier).acknowledgeDebt(debt.id);
                  ref.invalidate(myBillsProvider);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isHighlight
                ? (isDark ? AppColors.bodyOnDark : AppColors.ink)
                : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 13,
            fontWeight: FontWeight.bold,
            color: valueColor ??
                (isHighlight
                    ? const Color(0xFFFF9500)
                    : (isDark ? AppColors.bodyOnDark : AppColors.ink)),
          ),
        ),
      ],
    );
  }
}

class SwipeToAcknowledgeButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onAcknowledge;

  const SwipeToAcknowledgeButton({
    super.key,
    required this.label,
    required this.onAcknowledge,
  });

  @override
  State<SwipeToAcknowledgeButton> createState() => _SwipeToAcknowledgeButtonState();
}

class _SwipeToAcknowledgeButtonState extends State<SwipeToAcknowledgeButton> {
  double _dragPosition = 0.0;
  bool _isAcknowledging = false;

  @override
  Widget build(BuildContext context) {
    const double totalHeight = 52.0;
    const double thumbSize = 44.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - thumbSize - 8.0;

        return Container(
          height: totalHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9500), Color(0xFFFF5000)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Center Label
              Center(
                child: _isAcknowledging
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ],
                      ),
              ),

              // Draggable Thumb
              if (!_isAcknowledging)
                Positioned(
                  left: 4.0 + _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _dragPosition = (_dragPosition + details.delta.dx)
                            .clamp(0.0, maxDrag);
                      });
                    },
                    onHorizontalDragEnd: (details) async {
                      if (_dragPosition >= maxDrag * 0.75) {
                        setState(() {
                          _dragPosition = maxDrag;
                          _isAcknowledging = true;
                        });
                        HapticFeedback.heavyImpact();
                        try {
                          await widget.onAcknowledge();
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _dragPosition = 0.0;
                              _isAcknowledging = false;
                            });
                          }
                        }
                      } else {
                        setState(() {
                          _dragPosition = 0.0;
                        });
                      }
                    },
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFFFF9500),
                        size: 22,
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
