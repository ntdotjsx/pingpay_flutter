import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/theme.dart';
import '../../models/ocr_models.dart';
import 'bill_items_bottom_sheet.dart';

class BillItemsSummaryCard extends StatelessWidget {
  final List<ReceiptItemModel> items;
  final double billTotalAmount;
  final ValueChanged<List<ReceiptItemModel>> onItemsUpdated;

  const BillItemsSummaryCard({
    super.key,
    required this.items,
    required this.billTotalAmount,
    required this.onItemsUpdated,
  });

  void _openItemsBottomSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BillItemsBottomSheet(
        initialItems: items,
        billTotalAmount: billTotalAmount,
        onItemsUpdated: onItemsUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalItemsPrice = items.fold(
      0.0,
      (acc, item) => acc + (item.amount * item.quantity),
    );

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openItemsBottomSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const ShapeDecoration(
                    color: Color(0x1FFF5000),
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.format_list_bulleted_rounded,
                    color: Color(0xFFFF5000),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            items.isNotEmpty
                                ? 'รายการสินค้า (${items.length} รายการ)'
                                : 'รายการสินค้าและบริการ',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                          if (items.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '฿${totalItemsPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF5000),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items.isNotEmpty
                            ? 'แตะเพื่อแก้ไขหรือลบรายการสินค้า'
                            : 'ระบุรายการสินค้าเพื่อแยกยอดให้เพื่อน (ไม่บังคับ)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
