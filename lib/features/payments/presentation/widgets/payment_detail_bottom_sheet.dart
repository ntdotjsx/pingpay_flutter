import 'dart:convert';
import 'dart:io';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thai_promptpay/thai_promptpay.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pingpay_loading.dart';
import '../../../../core/utils/app_toast.dart';
import '../../models/payment_models.dart';
import '../../providers/payment_providers.dart';
import '../../services/debt_age_calculator.dart';

class PaymentDetailBottomSheet extends ConsumerStatefulWidget {
  final DebtItemModel debt;

  const PaymentDetailBottomSheet({super.key, required this.debt});

  static Future<void> show(BuildContext context, DebtItemModel debt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PaymentDetailBottomSheet(debt: debt),
      ),
    );
  }

  @override
  ConsumerState<PaymentDetailBottomSheet> createState() =>
      _PaymentDetailBottomSheetState();
}

class _PaymentDetailBottomSheetState
    extends ConsumerState<PaymentDetailBottomSheet> {
  final _amountController = TextEditingController();
  final _picker = ImagePicker();

  bool _isFullPayment = true;
  File? _selectedSlipFile;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.debt.outstandingAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectFullPayment() {
    setState(() {
      _isFullPayment = true;
      _amountController.text = widget.debt.outstandingAmount.toStringAsFixed(2);
    });
  }

  void _selectPartialPayment() {
    setState(() {
      _isFullPayment = false;
    });
  }

  Future<void> _pickSlipImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (picked != null) {
        setState(() {
          _selectedSlipFile = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking slip: $e');
    }
  }

  Future<void> _executePayment() async {
    final enteredAmount = double.tryParse(_amountController.text.trim());
    if (enteredAmount == null || enteredAmount <= 0) {
      AppToast.warning(context, 'กรุณาระบุจำนวนเงินที่ถูกต้อง (มากกว่า 0)');
      return;
    }

    if (enteredAmount > widget.debt.outstandingAmount) {
      AppToast.warning(
        context,
        'ยอดชำระ (${enteredAmount.toStringAsFixed(2)} ฿) เกินยอดค้าง (${widget.debt.outstandingAmount.toStringAsFixed(2)} ฿)',
      );
      return;
    }

    HapticFeedback.heavyImpact();

    final result = await ref
        .read(paymentFlowProvider.notifier)
        .submitPayment(
          billId: widget.debt.billId,
          participantId: widget.debt.id,
          amount: enteredAmount,
          slipFile: _selectedSlipFile,
          method: _isFullPayment ? 'full' : 'installment',
        );

    if (mounted && result != null) {
      Navigator.pop(context); // Close sheet
      _showPaymentResultModal(context, result);
    }
  }

  void _showPaymentResultModal(
    BuildContext context,
    CreatePaymentResultModel result,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ส่งหลักฐานสำเร็จ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ตรวจสอบสลิปผ่าน SlipOK สำเร็จ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'สถานะ: รอเจ้าของบิลยืนยันการรับเงิน\n(ระบบจะอัปเดตยอดหนี้เมื่อเจ้าของบิลกดยืนยัน)',
              style: TextStyle(fontSize: 13, color: AppColors.inkMuted48),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ยอดชำระครั้งนี้:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '฿${result.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'ตกลง',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paymentFlow = ref.watch(paymentFlowProvider);
    final historyAsync = ref.watch(
      billPaymentHistoryProvider(widget.debt.billId),
    );

    final debtAgeText = DebtAgeCalculator.formatDebtAgeThai(
      widget.debt.debtStartDate,
    );
    final formattedDate = DebtAgeCalculator.formatThaiDate(
      widget.debt.debtStartDate,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'รายละเอียดการชำระเงิน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bill & Creditor Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: ShapeDecoration(
                color: isDark
                    ? AppColors.surfaceTile2
                    : AppColors.canvasParchment,
                shape: SmoothRectangleBorder(
                  side: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.hairline,
                  ),
                  borderRadius: const SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.debt.billTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ต้องจ่ายให้ ${widget.debt.creditor.displayName} • $debtAgeText ($formattedDate)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.bodyMuted
                          : AppColors.inkMuted48,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniInfo(
                        'ยอดทั้งหมด',
                        '฿${widget.debt.currentAmount.toStringAsFixed(2)}',
                        isDark,
                      ),
                      _buildMiniInfo(
                        'ชำระแล้ว',
                        '฿${widget.debt.amountPaid.toStringAsFixed(2)}',
                        isDark,
                      ),
                      _buildMiniInfo(
                        'ยอดค้าง',
                        '฿${widget.debt.outstandingAmount.toStringAsFixed(2)}',
                        isDark,
                        isHighlight: true,
                      ),
                    ],
                  ),

                  // Receipt / Evidence Image Thumbnail if available
                  if (widget.debt.receiptImageUrl != null &&
                      widget.debt.receiptImageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? Colors.white10 : AppColors.dividerSoft,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'หลักฐานบิล / ใบเสร็จจากเพื่อน',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showFullReceiptDialog(context, widget.debt.receiptImageUrl!),
                      child: Container(
                        height: 90,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : AppColors.hairline,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              widget.debt.receiptImageUrl!.startsWith('data:image')
                                  ? Image.memory(
                                      base64Decode(
                                        widget.debt.receiptImageUrl!.replaceFirst(
                                          RegExp(r'data:image/[^;]+;base64,'),
                                          '',
                                        ),
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, _, __) => const Center(
                                        child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                                      ),
                                    )
                                  : Image.network(
                                      widget.debt.receiptImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, _, __) => const Center(
                                        child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                                      ),
                                    ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'แตะดูรูปเต็ม',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Option Selector (Pay in Full vs Installment)
            Text(
              'เลือกรูปแบบการชำระ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectFullPayment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isFullPayment
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.surfaceTile2
                                  : AppColors.canvasParchment),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isFullPayment
                              ? AppColors.primary
                              : (isDark ? Colors.white10 : AppColors.hairline),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'จ่ายเต็มจำนวน',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isFullPayment
                              ? Colors.white
                              : (isDark ? AppColors.bodyMuted : AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectPartialPayment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isFullPayment
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.surfaceTile2
                                  : AppColors.canvasParchment),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !_isFullPayment
                              ? AppColors.primary
                              : (isDark ? Colors.white10 : AppColors.hairline),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'จ่ายบางส่วน',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: !_isFullPayment
                              ? Colors.white
                              : (isDark ? AppColors.bodyMuted : AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: ShapeDecoration(
                color: isDark
                    ? AppColors.surfaceTile2
                    : AppColors.canvasParchment,
                shape: SmoothRectangleBorder(
                  side: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.hairline,
                  ),
                  borderRadius: const SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '฿',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ยอดชำระครั้งนี้ (บาท)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMuted48,
                          ),
                        ),
                        TextField(
                          controller: _amountController,
                          readOnly: _isFullPayment,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.bodyOnDark
                                : AppColors.ink,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(top: 4, bottom: 4),
                          ),
                          onChanged: (_) {
                            setState(() {}); // Re-generate dynamic QR on amount edit
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // PromptPay QR & Bank Account Section
            _buildPromptPayAndBankCard(isDark),

            const SizedBox(height: 20),

            // Slip Upload Card
            Text(
              'แนบสลิปการโอนเงิน (ตรวจสอบผ่าน SlipOK)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: () {
                _showImageSourceDialog();
              },
              child: Container(
                height: 120,
                decoration: ShapeDecoration(
                  color: isDark
                      ? AppColors.surfaceTile2
                      : AppColors.canvasParchment,
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: _selectedSlipFile != null
                          ? AppColors.primary
                          : (isDark ? Colors.white10 : AppColors.hairline),
                      width: _selectedSlipFile != null ? 1.5 : 1,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: _selectedSlipFile != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'แนบสลิปเรียบร้อยแล้ว (แตะเพื่อเปลี่ยน)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.bodyOnDark
                                  : AppColors.ink,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted48,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'แตะเพื่ออัปโหลดสลิปจากอัลบั้มหรือถ่ายรูป',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.bodyMuted
                                  : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            if (paymentFlow.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                paymentFlow.errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: paymentFlow.isSubmitting ? null : _executePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: paymentFlow.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'ดำเนินการชำระเงิน',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            // Payment History / Installments Section
            const SizedBox(height: 24),
            Text(
              'ประวัติการชำระบิลนี้ (Installments)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),

            historyAsync.when(
              data: (history) {
                if (history.isEmpty) {
                  return Text(
                    'ยังไม่มีประวัติการชำระเงินสำหรับบิลนี้',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.bodyMuted
                          : AppColors.inkMuted48,
                    ),
                  );
                }

                return Column(
                  children: history.map((item) {
                    final isConfirmed = item.status == 'confirmed';
                    final dateStr = DebtAgeCalculator.formatThaiDate(
                      item.createdAt,
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceTile2
                            : AppColors.canvasParchment,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'งวดที่ #${item.installmentNumber ?? 1} • $dateStr',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.bodyOnDark
                                      : AppColors.ink,
                                ),
                              ),
                              Text(
                                isConfirmed ? 'ยืนยันแล้ว' : 'รอเจ้าของยืนยัน',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isConfirmed
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '฿${item.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.bodyOnDark
                                  : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const PingPayLoadingWidget(size: 80),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('เลือกจากอัลบั้มรูป'),
              onTap: () {
                Navigator.pop(ctx);
                _pickSlipImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('ถ่ายรูปสลิป'),
              onTap: () {
                Navigator.pop(ctx);
                _pickSlipImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptPayAndBankCard(bool isDark) {
    final creditor = widget.debt.creditor;
    final promptPayId = creditor.promptPayId;
    final bankAcc = creditor.bankAccountNumber;
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    String? qrPayload;
    if (promptPayId != null && promptPayId.isNotEmpty) {
      try {
        final cleanId = promptPayId.replaceAll(RegExp(r'[^0-9]'), '');
        final satang = enteredAmount > 0 ? (enteredAmount * 100).round() : null;
        
        if (cleanId.length == 13) {
          qrPayload = encodePromptPay(
            target: PromptPayTarget(PromptPayType.nationalId, cleanId),
            amountSatang: satang,
          );
        } else if (cleanId.length == 15) {
          qrPayload = encodePromptPay(
            target: PromptPayTarget(PromptPayType.eWallet, cleanId),
            amountSatang: satang,
          );
        } else {
          // Default to mobile
          qrPayload = promptPayMobile(cleanId, amountSatang: satang);
        }
      } catch (e) {
        debugPrint('PromptPayQR generate error: $e');
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment,
        shape: const SmoothRectangleBorder(
          side: BorderSide(
            color: AppColors.hairline,
          ),
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF003D6B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xFF003D6B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'พร้อมเพย์ / บัญชีรับเงินของ ${creditor.displayName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                    Text(
                      'สแกน QR ผ่านแอปธนาคารเพื่อโอนเงินตามยอดที่ระบุ',
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
          const SizedBox(height: 16),

          // PromptPay QR Display
          if (qrPayload != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // PromptPay Header Logo/Text
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF003D6B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PromptPay พร้อมเพย์',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 180.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ยอดโอน: ฿${enteredAmount > 0 ? enteredAmount.toStringAsFixed(2) : widget.debt.outstandingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003D6B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // PromptPay ID & Bank Info List
          if (promptPayId != null && promptPayId.isNotEmpty)
            _buildCopyableInfoRow(
              icon: Icons.phone_android_rounded,
              label: 'เบอร์พร้อมเพย์',
              value: promptPayId,
              isDark: isDark,
            ),

          if (bankAcc != null && bankAcc.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildCopyableInfoRow(
              icon: Icons.account_balance_rounded,
              label: 'เลขที่บัญชีธนาคาร',
              value: bankAcc,
              isDark: isDark,
            ),
          ],

          if ((promptPayId == null || promptPayId.isEmpty) &&
              (bankAcc == null || bankAcc.isEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Text(
                  'เพื่อนคนนี้ยังไม่ได้ตั้งค่าพร้อมเพย์หรือเลขบัญชีธนาคาร',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCopyableInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.hairline,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              AppToast.success(context, 'คัดลอก $value เรียบร้อยแล้ว');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'คัดลอก',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(
    String title,
    String val,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? AppColors.primary
                : (isDark ? AppColors.bodyOnDark : AppColors.ink),
          ),
        ),
      ],
    );
  }
}
