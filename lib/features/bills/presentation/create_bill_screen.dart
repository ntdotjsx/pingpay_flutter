import 'dart:convert';
import 'dart:io';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/pingpay_loading.dart';
import '../../../core/utils/app_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../../friends/models/friend_models.dart';
import '../../friends/providers/friends_provider.dart';
import '../../payments/providers/payment_providers.dart';
import '../../profile/presentation/widgets/setup_payment_channel_sheet.dart';
import '../models/ocr_models.dart';
import '../providers/bill_provider.dart';
import '../providers/ocr_provider.dart';
import 'bill_split_editor.dart';
import 'no_friends_state_widget.dart';
import 'widgets/bill_confirmation_bottom_sheet.dart';
import 'widgets/bill_items_summary_card.dart';
import 'widgets/bill_items_bottom_sheet.dart';
import 'widgets/destructive_confirmation_sheet.dart';
import 'widgets/selected_friends_horizontal_bar.dart';

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  // Form Controllers
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    _titleController.addListener(_onTitleChanged);
  }

  void _onAmountChanged() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    ref
        .read(billCreationProvider.notifier)
        .setBillInfo(
          title: _titleController.text.trim(),
          totalAmount: amount,
          description: _descriptionController.text.trim(),
        );
  }

  void _onTitleChanged() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    ref
        .read(billCreationProvider.notifier)
        .setBillInfo(
          title: _titleController.text.trim(),
          totalAmount: amount,
          description: _descriptionController.text.trim(),
        );
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showScanReceiptActionSheet(BuildContext context) async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceBlack : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const ShapeDecoration(
                      color: Color(0x1FFF5000),
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: Color(0xFFFF5000),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สแกนใบเสร็จด้วย AI',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          ),
                        ),
                        Text(
                          'ระบบจะอ่านรายการสินค้าและยอดเงินให้อัตโนมัติ',
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
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text(
                  'ถ่ายภาพใบเสร็จ (กล้อง)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5000),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text(
                  'เลือกจากอัลบั้มรูปภาพ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final user = ref.read(authStateProvider).user;
    final promptPayId = user?.promptPayId ?? user?.phoneNumber ?? '';

    if (promptPayId.isEmpty) {
      final saved = await SetupPaymentChannelSheet.show(context);
      if (saved != true) return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      try {
        final bytes = await file.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        ref.read(billCreationProvider.notifier).setReceiptImageBase64(base64String);
      } catch (_) {}

      if (!mounted) return;
      _showScanningLoadingDialog();

      try {
        final result = await ref
            .read(ocrScanProvider.notifier)
            .scanReceipt(file);
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();

        if (result != null) {
          _populateBillFromOcr(result);
        } else {
          final err = ref.read(ocrScanProvider).errorMessage;
          AppToast.error(context, err ?? 'ไม่สามารถดึงข้อมูลจากรูปภาพได้');
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }

  void _showScanningLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.surfaceTile1
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PingPayLoadingWidget(size: 60),
              const SizedBox(height: 16),
              const Text(
                'กำลังวิเคราะห์สลิปด้วย AI...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ระบบกำลังสกัดรายการสินค้าและยอดรวมอัตโนมัติ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.bodyMuted
                      : AppColors.inkMuted80,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openItemsSummarySheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final billState = ref.read(billCreationProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BillItemsBottomSheet(
        initialItems: billState.items,
        billTotalAmount: billState.totalAmount,
        onItemsUpdated: (newItems) {
          ref.read(billCreationProvider.notifier).setItems(newItems);
          _amountController.text = ref.read(billCreationProvider).totalAmount.toStringAsFixed(2);
        },
      ),
    );
  }

  void _populateBillFromOcr(ReceiptOcrResultModel receipt) {
    _titleController.text = receipt.merchant;
    _amountController.text = receipt.totalAmount.toStringAsFixed(2);

    ref.read(billCreationProvider.notifier).populateFromOcr(receipt);

    AppToast.success(
      context,
      'ดึงข้อมูลจาก "${receipt.merchant}" ยอด ฿${receipt.totalAmount.toStringAsFixed(2)} เรียบร้อย',
    );
  }

  Future<void> _showConfirmationSheet() async {
    final user = ref.read(authStateProvider).user;
    final promptPayId = user?.promptPayId ?? user?.phoneNumber ?? '';

    if (promptPayId.isEmpty) {
      final saved = await SetupPaymentChannelSheet.show(context);
      if (saved != true) return;
    }

    if (!mounted) return;
    final billState = ref.read(billCreationProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BillConfirmationBottomSheet(
        state: billState,
        onConfirm: () async {
          final bill = await ref
              .read(billCreationProvider.notifier)
              .submitBill();
          if (bill != null && mounted) {
            _titleController.clear();
            _amountController.clear();
            _descriptionController.clear();
            ref.read(billCreationProvider.notifier).reset();

            ref.invalidate(myBillsProvider);
            ref.read(userReceivablesProvider.notifier).loadReceivables(showLoading: false);
            ref.read(userDebtsProvider.notifier).loadDebts(showLoading: false);

            if (mounted) {
              AppToast.success(
                context,
                'สร้างบิล "${bill.title ?? 'บิลอาหาร'}" ยอด ฿${bill.totalAmount.toStringAsFixed(2)} สำเร็จ!',
              );

              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            }
          } else if (mounted) {
            final error = ref.read(billCreationProvider).errorMessage;
            if (error != null) {
              AppToast.error(context, error);
            }
          }
        },
      ),
    );
  }

  Future<void> _handleClearBill() async {
    final billState = ref.read(billCreationProvider);
    if (!billState.hasUnsavedChanges) return;

    final confirmed = await DestructiveConfirmationSheet.show(
      context,
      title: 'ล้างข้อมูลบิลนี้?',
      message:
          'ข้อมูลที่คุณกรอกไว้ทั้งหมดจะถูกล้างออก ข้อมูลที่ล้างแล้วจะไม่สามารถเรียกคืนได้',
      confirmLabel: 'ล้างข้อมูลบิล',
      cancelLabel: 'ยกเลิก',
      itemCount: billState.items.isNotEmpty ? billState.items.length : null,
      totalAmount: billState.totalAmount > 0 ? billState.totalAmount : null,
      icon: Icons.delete_sweep_rounded,
    );

    if (confirmed == true && mounted) {
      _titleController.clear();
      _amountController.clear();
      _descriptionController.clear();
      ref.read(billCreationProvider.notifier).reset();
      AppToast.info(context, 'ล้างข้อมูลบิลเรียบร้อยแล้ว');
    }
  }

  Future<bool> _handleBackNavigation() async {
    final billState = ref.read(billCreationProvider);
    if (!billState.hasUnsavedChanges) {
      return true;
    }

    final confirmed = await DestructiveConfirmationSheet.show(
      context,
      title: 'ออกจากการสร้างบิล?',
      message:
          'ข้อมูลที่คุณกรอกไว้ยังไม่ได้บันทึก หากออกจากหน้านี้ข้อมูลร่างจะถูกละทิ้ง',
      confirmLabel: 'ออกจากหน้านี้',
      cancelLabel: 'อยู่ต่อ',
      icon: Icons.exit_to_app_rounded,
    );

    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _handleBackNavigation();
        if (shouldLeave && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.surfaceBlack : Colors.white,
        body: friendsAsync.when(
          loading: () => const PingPayLoadingWidget(size: 120),
          error: (err, _) => Center(
            child: Text(
              'เกิดข้อผิดพลาด: $err',
              style: TextStyle(
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
          ),
          data: (friends) {
            if (friends.isEmpty) {
              return SafeArea(
                child: Column(
                  children: [
                    _buildTopAppBar(context),
                    const Spacer(),
                    const NoFriendsStateWidget(),
                    const Spacer(),
                  ],
                ),
              );
            }

            return _buildCreateBillContent(friends);
          },
        ),
      ),
    );
  }

  // ==========================================
  // VIEW: BILL CREATION FORM (CLEAN LIST INPUT & STICKY BOTTOM BUTTON)
  // ==========================================
  Widget _buildCreateBillContent(List<FriendItemModel> friends) {
    final billState = ref.watch(billCreationProvider);
    final billNotifier = ref.read(billCreationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopAppBar(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'กรอกข้อมูลและเลือกเพื่อนร่วมหารบิล',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            billState.participants.isNotEmpty
                                ? 'ร่วมหาร ${billState.participants.length} คน • ยอด ฿${billState.totalAmount.toStringAsFixed(2)}'
                                : 'ยังไม่ได้เลือกเพื่อนร่วมหารบิล',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Quick OCR Scan Pill in Header
                      GestureDetector(
                        onTap: () => _showScanReceiptActionSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.document_scanner_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'สแกนบิล AI',
                                style: TextStyle(
                                  fontSize: 11,
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
                ),
              ],
            ),
          ),
        ),

        // 2. Middle Scrollable Area: Clean List Inputs
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PromptPay Warning Banner if not set
                Consumer(
                  builder: (context, ref, _) {
                    final user = ref.watch(authStateProvider).user;
                    final promptPayId = user?.promptPayId ?? user?.phoneNumber ?? '';
                    if (promptPayId.isNotEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFEEBA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFF856404),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'ยังไม่ได้ตั้งค่าช่องทางรับเงิน',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'แตะเพื่อใส่พร้อมเพย์เพื่อให้เพื่อนโอนเงินคืนคุณได้',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => SetupPaymentChannelSheet.show(context),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5000),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('ตั้งค่า', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Group 1: Clean Inset-Grouped Bill Details Card
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Bill Name
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
                              Icons.receipt_long_rounded,
                              color: Color(0xFFFF5000),
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'ชื่อบิล / รายการ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _titleController,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: 'เช่น ค่าอาหารมื้อเย็น, ทริปหัวหิน...',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            fontWeight: FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          thickness: 0.6,
                          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                        ),
                      ),

                      // 2. Total Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                alignment: Alignment.center,
                                child: const Text(
                                  '฿',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF5000),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'ยอดรวมทั้งหมด (บาท)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => _openItemsSummarySheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFFFF5000)),
                                  SizedBox(width: 3),
                                  Text(
                                    'แยกรายการ',
                                    style: TextStyle(
                                      fontSize: 11,
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
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            '฿ ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF5000),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              readOnly: true,
                              onTap: () => _openItemsSummarySheet(context),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF5000),
                                letterSpacing: -0.5,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                fillColor: Colors.transparent,
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  fontSize: 22,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  fontWeight: FontWeight.bold,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Group 2: Items Breakdown (Clean Inset Card)
                BillItemsSummaryCard(
                  items: billState.items,
                  billTotalAmount: billState.totalAmount,
                  onItemsUpdated: (newItems) {
                    billNotifier.setItems(newItems);
                    _amountController.text = ref.read(billCreationProvider).totalAmount.toStringAsFixed(2);
                  },
                ),
                const SizedBox(height: 10),

                // Group 3: Evidence / Receipt Photo Attachment (Clean Inset Card)
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
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
                              Icons.camera_alt_rounded,
                              color: Color(0xFFFF5000),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'รูปใบเสร็จหลักฐาน',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                  ),
                                ),
                                Text(
                                  billState.receiptImageBase64 != null
                                      ? 'แนบรูปหลักฐานเรียบร้อยแล้ว'
                                      : 'แนบรูปเพื่อความโปร่งใส (ไม่บังคับ)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (billState.receiptImageBase64 != null)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                billNotifier.setReceiptImageBase64(null);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ลบรูป',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    try {
                                      final picked = await _picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1280,
                                        maxHeight: 1280,
                                        imageQuality: 75,
                                      );
                                      if (picked != null) {
                                        final bytes = await File(picked.path).readAsBytes();
                                        billNotifier.setReceiptImageBase64('data:image/jpeg;base64,${base64Encode(bytes)}');
                                      }
                                    } catch (_) {}
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.surfaceTile3 : const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.photo_library_rounded, size: 13),
                                        SizedBox(width: 4),
                                        Text('แกลเลอรี', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    try {
                                      final picked = await _picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 1280,
                                        maxHeight: 1280,
                                        imageQuality: 75,
                                      );
                                      if (picked != null) {
                                        final bytes = await File(picked.path).readAsBytes();
                                        billNotifier.setReceiptImageBase64('data:image/jpeg;base64,${base64Encode(bytes)}');
                                      }
                                    } catch (_) {}
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt_rounded, size: 13, color: Color(0xFFFF5000)),
                                        SizedBox(width: 4),
                                        Text('ถ่ายรูป', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFF5000))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (billState.receiptImageBase64 != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 140,
                            width: double.infinity,
                            color: Colors.black12,
                            child: Image.memory(
                              base64Decode(
                                billState.receiptImageBase64!.replaceFirst(
                                  RegExp(r'data:image/[^;]+;base64,'),
                                  '',
                                ),
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, _, __) => const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  size: 36,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Group 4: Friend Selection with Circular '+' and Horizontal Swiper
                SelectedFriendsHorizontalBar(
                  allFriends: friends,
                  selectedParticipants: billState.participants,
                  onFriendsSelected: (selectedList) {
                    billNotifier.setSelectedFriends(selectedList);
                  },
                  onRemoveParticipant: (userId) {
                    billNotifier.removeParticipant(userId);
                  },
                ),

                // Group 5: Deterministic Amount Splitting
                if (billState.participants.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const BillSplitEditor(),
                ],

                // Error Display
                if (billState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            billState.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
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
        ),

        // 3. STICKY PINNED BOTTOM ACTION BUTTON (ALWAYS AT THE VERY BOTTOM)
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceBlack : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed:
                  (billState.participants.isEmpty ||
                      billState.totalAmount <= 0 ||
                      billState.isSubmitting)
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _showConfirmationSheet();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5000),
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark ? AppColors.surfaceTile2 : const Color(0xFFE5E7EB),
                disabledForegroundColor: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: billState.isSubmitting
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
                        const Icon(Icons.check_circle_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          billState.totalAmount > 0
                              ? 'สร้างบิล (฿${billState.totalAmount.toStringAsFixed(2)})'
                              : 'สร้างบิล',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final billState = ref.watch(billCreationProvider);

    return Padding(
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
              onPressed: () async {
                final shouldLeave = await _handleBackNavigation();
                if (shouldLeave && context.mounted) {
                  context.pop();
                }
              },
            ),
          ),
          const Text(
            'สร้างบิลใหม่',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          if (billState.hasUnsavedChanges)
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
                  Icons.delete_sweep_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'ล้างข้อมูลบิล',
                onPressed: _handleClearBill,
              ),
            )
          else
            const SizedBox(width: 38),
        ],
      ),
    );
  }
}
