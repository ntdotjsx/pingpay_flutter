import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../providers/bill_provider.dart';

class BillConfirmationBottomSheet extends StatelessWidget {
  final BillCreationState state;
  final VoidCallback onConfirm;

  const BillConfirmationBottomSheet({
    super.key,
    required this.state,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title & Subtitle
            const Text(
              'ยืนยันการสร้างบิล (Confirm Bill)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'ระบบจะบันทึกรายการหนี้และส่งการแจ้งเตือนไปยังเพื่อนที่ร่วมหารบิล',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted48),
            ),

            const SizedBox(height: 16),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: ShapeDecoration(
                color: isDark
                    ? AppColors.surfaceTile2
                    : AppColors.canvasParchment,
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
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
                          state.title.isNotEmpty
                              ? state.title
                              : 'บิลค่าใช้จ่าย',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '฿${state.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (state.items.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'รายการสินค้า: ${state.items.length} รายการ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted48,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Accounting breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ยอดที่ฉันจ่ายสำรอง (Bill Total)',
                        style: TextStyle(fontSize: 12, color: AppColors.inkMuted80),
                      ),
                      Text(
                        '฿${state.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ส่วนของฉัน (My Share)',
                        style: TextStyle(fontSize: 12, color: AppColors.inkMuted80),
                      ),
                      Text(
                        state.includeOwner
                            ? '฿${state.ownerAmountBaht.toStringAsFixed(2)}'
                            : '฿0.00 (ไม่รวมฉัน)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: state.includeOwner ? AppColors.primary : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ยอดที่ต้องเก็บคืนจากเพื่อนทั้งหมด',
                        style: TextStyle(fontSize: 12, color: AppColors.inkMuted80),
                      ),
                      Text(
                        '฿${state.participants.fold(0.0, (acc, p) => acc + p.amountBaht).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  Text(
                    'รายชื่อเพื่อนที่หาร (${state.participants.length} คน):',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  ...state.participants.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '• ${p.displayName}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            '฿${p.amountBaht.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.receiptImageBase64 != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'แนบรูปหลักฐานใบเสร็จแล้ว (Base64)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'ย้อนกลับ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () {
                            Navigator.pop(context);
                            onConfirm();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'ยืนยันและสร้างบิล',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
