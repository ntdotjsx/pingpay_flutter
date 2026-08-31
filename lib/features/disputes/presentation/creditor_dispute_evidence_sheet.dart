import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/dispute_model.dart';
import '../providers/dispute_providers.dart';
import '../repositories/dispute_repository.dart';

class CreditorDisputeEvidenceSheet extends ConsumerStatefulWidget {
  final DisputeModel dispute;
  final String? billReceiptImageUrl;

  const CreditorDisputeEvidenceSheet({
    super.key,
    required this.dispute,
    this.billReceiptImageUrl,
  });

  static Future<bool?> show(
    BuildContext context, {
    required DisputeModel dispute,
    String? billReceiptImageUrl,
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
      builder: (context) => CreditorDisputeEvidenceSheet(
        dispute: dispute,
        billReceiptImageUrl: billReceiptImageUrl,
      ),
    );
  }

  @override
  ConsumerState<CreditorDisputeEvidenceSheet> createState() => _CreditorDisputeEvidenceSheetState();
}

class _CreditorDisputeEvidenceSheetState extends ConsumerState<CreditorDisputeEvidenceSheet> {
  late TextEditingController _noteController;
  late TextEditingController _evidenceUrlController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.dispute.creditorEvidenceNote ?? '');
    _evidenceUrlController = TextEditingController(text: widget.dispute.creditorEvidenceUrl ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    _evidenceUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final note = _noteController.text.trim();
    final evidenceUrl = _evidenceUrlController.text.trim();

    if (note.isEmpty && evidenceUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณาระบุข้อความคำชี้แจงหรือแนบหลักฐานเพิ่มเติม'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(disputeRepositoryProvider);
      await repository.submitCreditorEvidence(
        disputeId: widget.dispute.id,
        note: note.isNotEmpty ? note : null,
        evidenceUrl: evidenceUrl.isNotEmpty ? evidenceUrl : null,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('ส่งหลักฐานชี้แจงไปยังผู้ดูแลระบบเรียบร้อยแล้ว')),
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
    final dispute = widget.dispute;
    final debtorName = dispute.raisedBy?['displayName'] ??
        dispute.raisedBy?['fullName'] ??
        dispute.raisedBy?['userCode'] ??
        'ลูกหนี้';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
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

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตรวจสอบข้อพิพาท & ชี้แจงหลักฐาน',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ส่งหลักฐานแก้ต่างให้ผู้ดูแลระบบ (Developer Console) พิจารณา',
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

              // Debtor Claim Card
              Container(
                width: double.infinity,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ข้อร้องเรียนจาก: $debtorName',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dispute.status.labelTh,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dispute.reason,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                    if (dispute.evidenceUrl != null && dispute.evidenceUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.attachment_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'หลักฐานแนบ: ${dispute.evidenceUrl}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Existing Bill Receipt Card (if available)
              if (widget.billReceiptImageUrl != null && widget.billReceiptImageUrl!.isNotEmpty) ...[
                Text(
                  'ภาพใบเสร็จหลักของบิลนี้ (แนบไว้แล้วในระบบ)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                        cornerRadius: 14,
                        cornerSmoothing: 0.6,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.billReceiptImageUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.black12,
                            child: const Icon(Icons.receipt_long, size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ใบเสร็จรับเงินต้นฉบับ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ผู้ดูแลระบบสามารถตรวจสอบภาพนี้ได้ใน Developer Console อยู่แล้ว',
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
                const SizedBox(height: 20),
              ],

              // Creditor Counter-Evidence Inputs
              Text(
                'คำชี้แจงแก้ต่างจากเจ้าหนี้',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'พิมพ์คำชี้แจง เช่น มีการตกลงสั่งเมนูนี้ร่วมกัน หรือยอดเงินที่โอนเข้ามาไม่ครบ...',
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

              Text(
                'แนบลิงก์รูปภาพหลักฐานเพิ่มเติม / สลิป / แชท (ไม่บังคับ)',
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
                  hintText: 'https://... ลิงก์รูปภาพเพิ่มเติม',
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
                    backgroundColor: AppColors.primary,
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
                          'ส่งหลักฐานชี้แจง',
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
