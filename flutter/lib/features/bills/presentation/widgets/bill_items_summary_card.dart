import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
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
        color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openItemsBottomSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items.isNotEmpty
                            ? 'รายการทั้งหมด ${items.length} รายการ'
                            : 'รายการสินค้า (ไม่ระบุ)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      Text(
                        items.isNotEmpty
                            ? 'ยอดรวมรายการ ฿${totalItemsPrice.toStringAsFixed(2)} • แตะเพื่อดูรายละเอียด'
                            : 'แตะเพื่อเพิ่มรายการสินค้า (ถ้ามี)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.inkMuted48,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
