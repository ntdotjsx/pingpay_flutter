import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/thai_banks.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pingpay_loading.dart';
import '../../../../core/utils/app_toast.dart';
import '../../models/payment_models.dart';
import '../../providers/payment_providers.dart';
import '../../services/debt_age_calculator.dart';
import '../../services/easyslip_qr_service.dart';
import '../../../friends/providers/friend_nickname_provider.dart';

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
  Timer? _debounceQrTimer;

  bool _isFullPayment = true;
  File? _selectedSlipFile;

  int _selectedChannelTab = 0; // 0: PromptPay, 1: TrueMoney, 2: Bank Transfer
  EasySlipQrResult? _easySlipQrResult;
  bool _isLoadingQr = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.debt.outstandingAmount.toStringAsFixed(2);
    _initChannelAndFetchQr();
  }

  void _initChannelAndFetchQr() {
    final creditor = widget.debt.creditor;
    // Default to promptpay if available, else bank, else truemoney
    if (creditor.promptPayId != null && creditor.promptPayId!.isNotEmpty) {
      _selectedChannelTab = 0;
    } else if (creditor.bankAccountNumber != null && creditor.bankAccountNumber!.isNotEmpty) {
      _selectedChannelTab = 2;
    } else if (creditor.truemoneyPhone != null && creditor.truemoneyPhone!.isNotEmpty) {
      _selectedChannelTab = 1;
    }
    _fetchEasySlipQr();
  }

  Future<void> _fetchEasySlipQr() async {
    final creditor = widget.debt.creditor;
    final rawAmount = double.tryParse(_amountController.text.trim());
    final enteredAmount = (rawAmount != null && rawAmount > 0)
        ? rawAmount
        : widget.debt.outstandingAmount;

    String? targetNumber;
    String type = 'PROMPTPAY';

    if (_selectedChannelTab == 0) {
      targetNumber = creditor.promptPayId;
      type = 'PROMPTPAY';
    } else if (_selectedChannelTab == 1) {
      targetNumber = creditor.truemoneyPhone ?? creditor.promptPayId;
      type = 'TRUEMONEY';
    }

    if (targetNumber == null || targetNumber.isEmpty) {
      setState(() => _easySlipQrResult = null);
      return;
    }

    setState(() => _isLoadingQr = true);
    final res = await ref.read(easySlipQrServiceProvider).generateQr(
      type: type,
      msisdn: targetNumber,
      amount: enteredAmount > 0 ? enteredAmount : null,
    );

    if (mounted) {
      setState(() {
        _easySlipQrResult = res;
        _isLoadingQr = false;
      });
    }
  }

  @override
  void dispose() {
    _debounceQrTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _selectFullPayment() {
    _debounceQrTimer?.cancel();
    setState(() {
      _isFullPayment = true;
      _amountController.text = widget.debt.outstandingAmount.toStringAsFixed(2);
    });
    _fetchEasySlipQr();
  }

  void _selectPartialPayment() {
    _debounceQrTimer?.cancel();
    setState(() {
      _isFullPayment = false;
    });
    _fetchEasySlipQr();
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

    final result = await ref.read(paymentFlowProvider.notifier).submitPayment(
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
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFFFF5000)),
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
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
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

    final nicknamesMap = ref.watch(friendNicknameProvider);
    final creditorNick = nicknamesMap[widget.debt.creditor.id] ?? nicknamesMap[widget.debt.creditor.userCode];
    final hasCreditorNick = creditorNick != null && creditorNick.trim().isNotEmpty;
    final effectiveCreditorName = hasCreditorNick ? creditorNick : widget.debt.creditor.displayName;

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
                color:
                    isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
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
                            color:
                                isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasCreditorNick
                              ? 'ต้องจ่ายให้ $effectiveCreditorName (${widget.debt.creditor.displayName}) • $debtAgeText ($formattedDate)'
                              : 'ต้องจ่ายให้ $effectiveCreditorName • $debtAgeText ($formattedDate)',
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                          color:
                              isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                        ),
                        _buildMiniInfo(
                          'ชำระแล้ว',
                          '฿${widget.debt.amountPaid.toStringAsFixed(2)}',
                          isDark,
                        ),
                        Container(
                          width: 0.6,
                          height: 24,
                          color:
                              isDark ? Colors.white10 : const Color(0xFFE5E7EB),
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
                                      color: isDark
                                          ? AppColors.bodyOnDark
                                          : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => _showFullReceiptDialog(
                                    context, widget.debt.receiptImageUrl!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5000)
                                        .withValues(alpha: 0.1),
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
                            onTap: () => _showFullReceiptDialog(
                                context, widget.debt.receiptImageUrl!),
                            child: Container(
                              height: 80,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : const Color(0xFFE5E7EB),
                                  width: 0.8,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: widget.debt.receiptImageUrl!
                                        .startsWith('data:image')
                                    ? Image.memory(
                                        base64Decode(
                                          widget.debt.receiptImageUrl!
                                              .replaceFirst(
                                            RegExp(r'data:image/[^;]+;base64,'),
                                            '',
                                          ),
                                        ),
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, _, __) =>
                                            const Center(
                                          child: Icon(
                                              Icons.broken_image_rounded,
                                              color: Colors.grey,
                                              size: 24),
                                        ),
                                      )
                                    : Image.network(
                                        widget.debt.receiptImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, _, __) =>
                                            const Center(
                                          child: Icon(
                                              Icons.broken_image_rounded,
                                              color: Colors.grey,
                                              size: 24),
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

            // Group 2: Payment Selector & Hero Amount Input
            Container(
              decoration: ShapeDecoration(
                color:
                    isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
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
                        color:
                            isDark ? Colors.black26 : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectFullPayment,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: _isFullPayment
                                      ? (isDark
                                          ? AppColors.surfaceTile1
                                          : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _isFullPayment
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
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
                                    fontWeight: _isFullPayment
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: _isFullPayment
                                        ? const Color(0xFFFF5000)
                                        : (isDark
                                            ? AppColors.bodyMuted
                                            : AppColors.inkMuted48),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectPartialPayment,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: !_isFullPayment
                                      ? (isDark
                                          ? AppColors.surfaceTile1
                                          : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !_isFullPayment
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
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
                                    fontWeight: !_isFullPayment
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: !_isFullPayment
                                        ? const Color(0xFFFF5000)
                                        : (isDark
                                            ? AppColors.bodyMuted
                                            : AppColors.inkMuted48),
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

                  // Spacious, Clean FinTech Hero Amount Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ยอดเงินที่ต้องการชำระ (บาท)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.bodyMuted
                                    : AppColors.inkMuted48,
                              ),
                            ),
                            if (!_isFullPayment)
                              Text(
                                'ยอดค้าง ฿${widget.debt.outstandingAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF5000),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              '฿ ',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF5000),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                readOnly: _isFullPayment,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  FocusScope.of(context).unfocus();
                                  _debounceQrTimer?.cancel();
                                  final rawAmount = double.tryParse(_amountController.text.trim());
                                  if (rawAmount != null && rawAmount > widget.debt.outstandingAmount) {
                                    AppToast.warning(context, 'ยอดชำระบางส่วนต้องไม่เกินยอดค้างชำระ (฿${widget.debt.outstandingAmount.toStringAsFixed(2)})');
                                  }
                                  _fetchEasySlipQr();
                                },
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: Color(0xFFFF5000),
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: '0.00',
                                  hintStyle: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: (isDark
                                            ? AppColors.bodyMuted
                                            : AppColors.inkMuted48)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                onChanged: (_) {
                                  _debounceQrTimer?.cancel();
                                  _debounceQrTimer = Timer(const Duration(milliseconds: 500), () {
                                    _fetchEasySlipQr();
                                  });
                                  setState(() {}); // Re-generate dynamic label immediately
                                },
                              ),
                            ),
                            if (_isFullPayment)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5000)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'เต็มจำนวน',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF5000),
                                  ),
                                ),
                              )
                            else
                              InkWell(
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  _debounceQrTimer?.cancel();
                                  final rawAmount = double.tryParse(_amountController.text.trim());
                                  if (rawAmount != null && rawAmount > widget.debt.outstandingAmount) {
                                    AppToast.warning(context, 'ยอดชำระบางส่วนต้องไม่เกินยอดค้างชำระ (฿${widget.debt.outstandingAmount.toStringAsFixed(2)})');
                                  }
                                  _fetchEasySlipQr();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5000),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF5000).withValues(alpha: 0.28),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'อัปเดต QR',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
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
                color:
                    isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
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
                            color:
                                isDark ? AppColors.bodyOnDark : AppColors.ink,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          color: isDark
                                              ? AppColors.bodyMuted
                                              : AppColors.inkMuted48,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : const Color(0xFFE5E7EB),
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
                                  color: isDark
                                      ? AppColors.bodyMuted
                                      : AppColors.inkMuted48,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'แตะเพื่ออัปโหลดสลิปจากอัลบั้มหรือถ่ายรูป',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.bodyMuted
                                        : AppColors.inkMuted48,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        color:
                            isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      ),
                    ),
                  );
                }

                return Container(
                  decoration: ShapeDecoration(
                    color: isDark
                        ? AppColors.surfaceTile2
                        : const Color(0xFFF9FAFB),
                    shape: SmoothRectangleBorder(
                      side: BorderSide(
                        color:
                            isDark ? Colors.white10 : const Color(0xFFE5E7EB),
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
                                  isConfirmed
                                      ? 'ยืนยันแล้ว'
                                      : 'รอเจ้าของยืนยัน',
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
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFFFF5000)),
              title: const Text('เลือกจากอัลบั้มรูป',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickSlipImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFFFF5000)),
              title: const Text('ถ่ายรูปสลิป',
                  style: TextStyle(fontWeight: FontWeight.w600)),
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
    final truemoneyPhone = creditor.truemoneyPhone;
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? widget.debt.outstandingAmount;

    final nicknamesMap = ref.watch(friendNicknameProvider);
    final creditorNick = nicknamesMap[creditor.id] ?? nicknamesMap[creditor.userCode];
    final hasCreditorNick = creditorNick != null && creditorNick.trim().isNotEmpty;
    final effectiveCreditorName = hasCreditorNick ? creditorNick : creditor.displayName;
    final creditorRealName = (creditor.fullName != null && creditor.fullName!.trim().isNotEmpty)
        ? creditor.fullName!
        : creditor.displayName;

    final hasPromptPay = promptPayId != null && promptPayId.isNotEmpty;
    final hasTrueMoney = truemoneyPhone != null && truemoneyPhone.isNotEmpty;
    final hasBank = bankAcc != null && bankAcc.isNotEmpty;

    // Resolve Bank details if available
    ThaiBank? matchedBank;
    if (creditor.bankCode != null && creditor.bankCode!.isNotEmpty) {
      try {
        matchedBank = kThaiBanks.firstWhere((b) => b.code.toLowerCase() == creditor.bankCode!.toLowerCase());
      } catch (_) {}
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
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const ShapeDecoration(
                    color: Color(0x1FFF5000),
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 8, cornerSmoothing: 0.8),
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFFFF5000),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ช่องทางชำระเงินของ $effectiveCreditorName',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      Text(
                        'ชื่อบัญชีจริง: $creditorRealName',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Multi-Channel Selection Tabs
          if (hasPromptPay || hasTrueMoney || hasBank) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  if (hasPromptPay)
                    Expanded(
                      child: _buildChannelTabButton(
                        tabIndex: 0,
                        label: 'พร้อมเพย์',
                        icon: Icons.qr_code_rounded,
                        activeColor: const Color(0xFF003D6B),
                        isDark: isDark,
                      ),
                    ),
                  if (hasTrueMoney) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildChannelTabButton(
                        tabIndex: 1,
                        label: 'TrueMoney',
                        icon: Icons.account_balance_wallet_rounded,
                        activeColor: const Color(0xFFFF8200),
                        isDark: isDark,
                      ),
                    ),
                  ],
                  if (hasBank) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildChannelTabButton(
                        tabIndex: 2,
                        label: 'โอนธนาคาร',
                        icon: Icons.account_balance_rounded,
                        activeColor: const Color(0xFF007AFF),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),

          // ── Tab 0 & 1: EasySlip QR Code View ────────────────────────────
          if (_selectedChannelTab == 0 || _selectedChannelTab == 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
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
                      // Badge Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _selectedChannelTab == 0 ? const Color(0xFF003D6B) : const Color(0xFFFF8200),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _selectedChannelTab == 0 ? 'PromptPay พร้อมเพย์ (EasySlip)' : 'TrueMoney Wallet (EasySlip)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // QR Code Image or Placeholder
                      if (_isLoadingQr)
                        const SizedBox(
                          width: 160,
                          height: 160,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFFFF5000),
                            ),
                          ),
                        )
                      else if (_easySlipQrResult?.imageBase64 != null &&
                          _easySlipQrResult!.imageBase64!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(_easySlipQrResult!.imageBase64!),
                            width: 160,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        )
                      else if (_easySlipQrResult?.payload != null &&
                          _easySlipQrResult!.payload!.isNotEmpty)
                        QrImageView(
                          data: _easySlipQrResult!.payload!,
                          version: QrVersions.auto,
                          size: 160.0,
                          backgroundColor: Colors.white,
                        )
                      else
                        Container(
                          width: 160,
                          height: 160,
                          alignment: Alignment.center,
                          child: const Text(
                            'ไม่พบข้อมูล QR',
                            style: TextStyle(fontSize: 12, color: AppColors.inkMuted48),
                          ),
                        ),

                      const SizedBox(height: 6),
                      Text(
                        'ยอดโอน: ฿${enteredAmount > 0 ? enteredAmount.toStringAsFixed(2) : widget.debt.outstandingAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedChannelTab == 0 ? const Color(0xFF003D6B) : const Color(0xFFFF8200),
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

          // ── Account / Identifier Copy Rows ──────────────────────────────
          if (_selectedChannelTab == 0 && hasPromptPay) ...[
            _buildCopyableInfoRow(
              icon: Icons.phone_android_rounded,
              label: 'เบอร์พร้อมเพย์ / รหัสผู้รับ',
              value: promptPayId!,
              isDark: isDark,
            ),
          ] else if (_selectedChannelTab == 1 && hasTrueMoney) ...[
            _buildCopyableInfoRow(
              icon: Icons.account_balance_wallet_rounded,
              label: 'เบอร์ TrueMoney Wallet',
              value: truemoneyPhone!,
              isDark: isDark,
            ),
          ] else if (_selectedChannelTab == 2 && hasBank) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (matchedBank != null)
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: matchedBank.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        matchedBank.logoCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.account_balance_rounded, size: 28, color: Color(0xFF007AFF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creditor.bankName ?? matchedBank?.name ?? 'บัญชีธนาคาร',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'เลขที่บัญชี: ${creditor.bankAccountNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF007AFF)),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Clipboard.setData(ClipboardData(text: creditor.bankAccountNumber!));
                      AppToast.success(context, 'คัดลอกเลขบัญชีธนาคารแล้ว');
                    },
                  ),
                ],
              ),
            ),
          ],

          if (!hasPromptPay && !hasTrueMoney && !hasBank)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Center(
                child: Text(
                  'เพื่อนคนนี้ยังไม่ได้ตั้งค่าช่องทางชำระเงิน',
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

  Widget _buildChannelTabButton({
    required int tabIndex,
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool isDark,
  }) {
    final isSelected = _selectedChannelTab == tabIndex;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedChannelTab = tabIndex);
        _fetchEasySlipQr();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? Colors.white10 : const Color(0xFFF0F2F5)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeColor : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : (isDark ? AppColors.bodyMuted : AppColors.ink),
              ),
            ),
          ],
        ),
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
