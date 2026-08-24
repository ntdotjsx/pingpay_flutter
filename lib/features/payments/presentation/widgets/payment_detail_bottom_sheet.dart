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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF34C759),
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ส่งหลักฐานสำเร็จ',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ตรวจสอบสลิปผ่าน EasySlip สำเร็จ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'สถานะ: ชำระเงินสำเร็จ\n(ระบบตรวจสอบสลิปและตัดยอดหนี้อัตโนมัติเรียบร้อยแล้ว)',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF34C759)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5000).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
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
                      color: Color(0xFFFF5000),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5000)),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'รายละเอียดการชำระเงิน',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Group 1: Bill & Creditor Summary Card (Clean Inset-Grouped Card)
            Container(
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.debt.billTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ต้องจ่ายให้ ${widget.debt.creditor.displayName} • $debtAgeText ($formattedDate)',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted48,
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

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniInfo(
                          'ยอดทั้งหมด',
                          '฿${widget.debt.currentAmount.toStringAsFixed(2)}',
                          isDark,
                        ),
                        Container(
                          width: 0.6,
                          height: 24,
                          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                        ),
                        _buildMiniInfo(
                          'ชำระแล้ว',
                          '฿${widget.debt.amountPaid.toStringAsFixed(2)}',
                          isDark,
                        ),
                        Container(
                          width: 0.6,
                          height: 24,
                          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                        ),
                        _buildMiniInfo(
                          'ยอดค้าง',
                          '฿${widget.debt.outstandingAmount.toStringAsFixed(2)}',
                          isDark,
                          isHighlight: true,
                        ),
                      ],
                    ),
                  ),

                  // Receipt / Evidence Image Thumbnail if available
                  if (widget.debt.receiptImageUrl != null &&
                      widget.debt.receiptImageUrl!.isNotEmpty) ...[
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
                                    'หลักฐานบิล / ใบเสร็จจากเพื่อน',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => _showFullReceiptDialog(context, widget.debt.receiptImageUrl!),
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
                            onTap: () => _showFullReceiptDialog(context, widget.debt.receiptImageUrl!),
                            child: Container(
                              height: 80,
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
                                child: widget.debt.receiptImageUrl!.startsWith('data:image')
                                    ? Image.memory(
                                        base64Decode(
                                          widget.debt.receiptImageUrl!.replaceFirst(
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
                                        widget.debt.receiptImageUrl!,
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
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Group 2: Payment Selector & List Input (Clean iOS/FinTech List Input)
            Container(
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
                  // iOS Segmented Style Selector
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectFullPayment,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: _isFullPayment
                                      ? (isDark ? AppColors.surfaceTile1 : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _isFullPayment
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'จ่ายเต็มจำนวน',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: _isFullPayment ? FontWeight.w800 : FontWeight.w600,
                                    color: _isFullPayment
                                        ? const Color(0xFFFF5000)
                                        : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectPartialPayment,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: !_isFullPayment
                                      ? (isDark ? AppColors.surfaceTile1 : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !_isFullPayment
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'จ่ายบางส่วน',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: !_isFullPayment ? FontWeight.w800 : FontWeight.w600,
                                    color: !_isFullPayment
                                        ? const Color(0xFFFF5000)
                                        : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                  ),

                  // Clean List Input Row (Eliminated nested child-like boxes)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                          alignment: Alignment.center,
                          child: const Text(
                            '฿',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF5000),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ยอดชำระครั้งนี้ (บาท)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _isFullPayment ? 'ยอดคงค้างเต็มจำนวน' : 'แตะเพื่อแก้ไขยอดที่ต้องการโอน',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IntrinsicWidth(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 90, maxWidth: 150),
                            child: TextField(
                              controller: _amountController,
                              readOnly: _isFullPayment,
                              textAlign: TextAlign.end,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: _isFullPayment
                                    ? (isDark ? AppColors.bodyOnDark : AppColors.ink)
                                    : const Color(0xFFFF5000),
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                suffixText: ' ฿',
                                suffixStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {}); // Re-generate dynamic QR on amount edit
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Group 3: PromptPay QR & Bank Account Section (Clean Inset Group)
            _buildPromptPayAndBankCard(isDark),

            const SizedBox(height: 12),

            // Group 4: Slip Upload Section (Clean Dropzone)
            Container(
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
                shape: SmoothRectangleBorder(
                  side: BorderSide(
                    color: _selectedSlipFile != null
                        ? const Color(0xFF34C759)
                        : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                    width: _selectedSlipFile != null ? 1.2 : 0.8,
                  ),
                  borderRadius: const SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.8),
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
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: Color(0xFFFF5000),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'แนบสลิปการโอนเงิน (ตรวจสอบผ่าน EasySlip)',
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
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _selectedSlipFile != null
                          ? Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedSlipFile!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF34C759),
                                            size: 16,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'แนบสลิปเรียบร้อยแล้ว',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF34C759),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'แตะเพื่อเลือกรูปใหม่หรือถ่ายใหม่',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'เปลี่ยนรูป',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 24,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'แตะเพื่ออัปโหลดสลิปจากอัลบั้มหรือถ่ายรูป',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            if (paymentFlow.errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paymentFlow.errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Submit Button (High-End FinTech CTA)
            ElevatedButton(
              onPressed: paymentFlow.isSubmitting ? null : _executePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5000),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: paymentFlow.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
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
            const SizedBox(height: 20),
            Text(
              'ประวัติการชำระบิลนี้ (Installments)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),

            historyAsync.when(
              data: (history) {
                if (history.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'ยังไม่มีประวัติการชำระเงินสำหรับบิลนี้',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.bodyMuted
                            : AppColors.inkMuted48,
                      ),
                    ),
                  );
                }

                return Container(
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
                    shape: SmoothRectangleBorder(
                      side: BorderSide(
                        color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                        width: 0.8,
                      ),
                      borderRadius: const SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                      ),
                    ),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.6,
                      indent: 14,
                      color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                    ),
                    itemBuilder: (ctx, idx) {
                      final item = history[idx];
                      final isConfirmed = item.status == 'confirmed';
                      final dateStr = DebtAgeCalculator.formatThaiDate(
                        item.createdAt,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.bodyOnDark
                                        : AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  isConfirmed ? 'ยืนยันแล้ว' : 'รอเจ้าของยืนยัน',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isConfirmed
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFF9500),
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
                    },
                  ),
                );
              },
              loading: () => const PingPayLoadingWidget(size: 60),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFFF5000)),
              title: const Text('เลือกจากอัลบั้มรูป', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickSlipImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF5000)),
              title: const Text('ถ่ายรูปสลิป', style: TextStyle(fontWeight: FontWeight.w600)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const ShapeDecoration(
                    color: Color(0x1F003D6B),
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 7, cornerSmoothing: 0.8),
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF003D6B),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'พร้อมเพย์ / บัญชีรับเงินของ ${creditor.displayName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      Text(
                        'สแกน QR ผ่านแอปธนาคารเพื่อโอนเงิน',
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
          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),

          // PromptPay QR Display
          if (qrPayload != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003D6B),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'PromptPay พร้อมเพย์',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 160.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ยอดโอน: ฿${enteredAmount > 0 ? enteredAmount.toStringAsFixed(2) : widget.debt.outstandingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003D6B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.6,
              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            ),
          ],

          // PromptPay ID & Bank Info List
          if (promptPayId != null && promptPayId.isNotEmpty) ...[
            _buildCopyableInfoRow(
              icon: Icons.phone_android_rounded,
              label: 'เบอร์พร้อมเพย์',
              value: promptPayId,
              isDark: isDark,
            ),
          ],

          if (bankAcc != null && bankAcc.isNotEmpty) ...[
            Divider(
              height: 1,
              thickness: 0.6,
              indent: 48,
              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            ),
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
              padding: const EdgeInsets.symmetric(vertical: 12.0),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFFFF5000)),
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
                fontSize: 12.5,
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
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.copy_rounded, size: 11, color: Color(0xFFFF5000)),
                  SizedBox(width: 3),
                  Text(
                    'คัดลอก',
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
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: isHighlight
                ? const Color(0xFFFF5000)
                : (isDark ? AppColors.bodyOnDark : AppColors.ink),
          ),
        ),
      ],
    );
  }
}
