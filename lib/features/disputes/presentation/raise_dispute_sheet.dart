import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/dispute_providers.dart';
import '../repositories/dispute_repository.dart';

class RaiseDisputeSheet extends ConsumerStatefulWidget {
  final String billItemId;
  final String billTitle;
  final double amount;
  final String creditorName;

  const RaiseDisputeSheet({
    super.key,
    required this.billItemId,
    required this.billTitle,
    required this.amount,
    required this.creditorName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String billItemId,
    required String billTitle,
    required double amount,
    required String creditorName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => RaiseDisputeSheet(
        billItemId: billItemId,
        billTitle: billTitle,
        amount: amount,
        creditorName: creditorName,
      ),
    );
  }

  @override
  ConsumerState<RaiseDisputeSheet> createState() => _RaiseDisputeSheetState();
}

class _RaiseDisputeSheetState extends ConsumerState<RaiseDisputeSheet> {
  final _reasonController = TextEditingController();
  final _evidenceUrlController = TextEditingController();
  String _selectedCategory = 'คิดยอดเงินไม่ถูกต้อง';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'คิดยอดเงินไม่ถูกต้อง',
    'ไม่ได้สั่ง / ไม่ได้ร่วมรายการนี้',
    'โอนเงินแล้วแต่ไม่กดยืนยัน',
    'ยอดหารไม่ตรงตามที่ตกลง',
    'อื่นๆ',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _evidenceUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final customReason = _reasonController.text.trim();
    final fullReason = customReason.isNotEmpty
        ? '[$_selectedCategory] $customReason'
        : _selectedCategory;

    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(disputeRepositoryProvider);
      await repository.raiseDispute(
        billItemId: widget.billItemId,
        reason: fullReason,
        evidenceUrl: _evidenceUrlController.text.trim().isNotEmpty
            ? _evidenceUrlController.text.trim()
            : null,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('ยื่นข้อพิพาทเรียบร้อยแล้ว ระบบได้แจ้งเตือนเจ้าหนี้แล้ว')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ยื่นข้อพิพาทเรื่องยอดหนี้',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'แจ้งเตือนเจ้าหนี้ (${widget.creditorName}) และส่งเรื่องให้ผู้ดูแลระบบตรวจสอบ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Bill & Amount Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                      cornerRadius: 16,
                      cornerSmoothing: 0.6,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'บิล:',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.billTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ยอดที่มีข้อพิพาท:',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '฿${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Category Selector
              Text(
                'เลือกประเภทของปัญหา',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    backgroundColor: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.bodyOnDark : AppColors.ink),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white12 : Colors.black12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Reason Textarea
              Text(
                'รายละเอียดเพิ่มเติม / เหตุผล',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'ระบุเหตุผล เช่น คำนวณยอดไม่ตรงตามรายการที่สั่ง หรือมีการจ่ายเงินไปก่อนหน้านี้แล้ว...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Optional Evidence URL
              Text(
                'ลิงก์หรือรูปภาพหลักฐาน (ไม่บังคับ)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _evidenceUrlController,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  hintText: 'https://... ลิงก์สลิป/หลักฐานการคุย',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'ยืนยันยื่นข้อพิพาท',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
