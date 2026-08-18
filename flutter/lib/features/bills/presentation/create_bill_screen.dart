import 'dart:io';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/theme.dart';
import '../../friends/models/friend_models.dart';
import '../../friends/providers/friends_provider.dart';
import '../models/ocr_models.dart';
import '../providers/bill_provider.dart';
import '../providers/ocr_provider.dart';
import 'bill_split_editor.dart';
import 'no_friends_state_widget.dart';
import 'widgets/bill_confirmation_bottom_sheet.dart';
import 'widgets/bill_items_summary_card.dart';
import 'widgets/destructive_confirmation_sheet.dart';
import 'widgets/selected_friends_horizontal_bar.dart';

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen>
    with SingleTickerProviderStateMixin {
  int _currentBottomNavIndex = 1; // 0 = สแกนบิล OCR, 1 = สร้างบิล
  int _cardTopTabIndex = 1; // 0 = จ่ายเงิน, 1 = สร้างบิล

  // Form Controllers
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Scanner animation
  late AnimationController _scannerAnimController;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (_currentBottomNavIndex == 0) {
      _scannerAnimController.repeat(reverse: true);
    }

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
    _scannerAnimController.dispose();
    _amountController.removeListener(_onAmountChanged);
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err ?? 'ไม่สามารถดึงข้อมูลจากรูปภาพได้'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showScanningLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 20),
              Text(
                'กำลังประมวลผล OCR ใบเสร็จ...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                'ระบบกำลังวิเคราะห์ร้านค้า รายการ และยอดรวม',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted48),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _populateBillFromOcr(ReceiptOcrResultModel receipt) {
    _titleController.text = receipt.merchant;
    _amountController.text = receipt.totalAmount.toStringAsFixed(2);

    ref.read(billCreationProvider.notifier).populateFromOcr(receipt);

    setState(() {
      _currentBottomNavIndex = 1;
      _cardTopTabIndex = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ดึงข้อมูลจาก "${receipt.merchant}" ยอด ฿${receipt.totalAmount.toStringAsFixed(2)} เรียบร้อย',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showConfirmationSheet() {
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'สร้างบิล "${bill.title}" ยอด ฿${bill.totalAmount} สำเร็จ!',
                ),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ล้างข้อมูลบิลเรียบร้อยแล้ว'),
          backgroundColor: AppColors.primary,
        ),
      );
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
        backgroundColor: _currentBottomNavIndex == 0
            ? Colors.black
            : (isDark ? AppColors.surfaceBlack : AppColors.primary),
        body: _currentBottomNavIndex == 0
            ? _buildCameraOcrScannerView()
            : friendsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'เกิดข้อผิดพลาด: $err',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                data: (friends) {
                  // RULE 1: ZERO FRIENDS RULE (MANDATORY)
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
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  // ==========================================
  // VIEW 1: CAMERA OCR SCANNER VIEW
  // ==========================================
  Widget _buildCameraOcrScannerView() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    const Text(
                      'สแกนบิล OCR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _isTorchOn
                            ? const Color(0xFFFFD700)
                            : Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isTorchOn = !_isTorchOn;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'รองรับใบเสร็จ สลิป และบิลค่าอาหารทุกชนิด',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'เลือกรูปจากอัลบั้ม',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: AppColors.primary,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 2: BILL CREATION FORM (MODULAR ARCHITECTURE)
  // ==========================================
  Widget _buildCreateBillContent(List<FriendItemModel> friends) {
    final billState = ref.watch(billCreationProvider);
    final billNotifier = ref.read(billCreationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 280,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppColors.surfaceTile1, AppColors.surfaceBlack]
                    : [
                        const Color(0xFFE53935),
                        const Color(0xFFFF5000),
                        const Color(0xFFFF6A00),
                      ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildTopAppBar(context),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: Container(
                    width: double.infinity,
                    decoration: ShapeDecoration(
                      color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segmented Tabs: [ จ่ายเงิน ] | [ สร้างบิล ]
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceTile2
                                : AppColors.canvasParchment,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _cardTopTabIndex = 0),
                                  child: Container(
                                    height: 36,
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: _cardTopTabIndex == 0
                                          ? (isDark
                                                ? AppColors.surfaceTile3
                                                : AppColors.canvas)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: _cardTopTabIndex == 0
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'จ่ายเงิน',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _cardTopTabIndex == 0
                                            ? AppColors.primary
                                            : AppColors.inkMuted48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _cardTopTabIndex = 1),
                                  child: Container(
                                    height: 36,
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: _cardTopTabIndex == 1
                                          ? (isDark
                                                ? AppColors.surfaceTile3
                                                : AppColors.canvas)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: _cardTopTabIndex == 1
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'สร้างบิล',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _cardTopTabIndex == 1
                                            ? AppColors.primary
                                            : AppColors.inkMuted48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Middle Scrollable Area: Form Inputs, Items, Friends & Split Editor
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Section 1: Bill Information (Modern FinTech & iOS-inspired Card Design)
                                Container(
                                  decoration: ShapeDecoration(
                                    color: isDark
                                        ? AppColors.surfaceTile2
                                        : AppColors.canvasParchment,
                                    shape: SmoothRectangleBorder(
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white10
                                            : AppColors.hairline,
                                      ),
                                      borderRadius:
                                          const SmoothBorderRadius.all(
                                            SmoothRadius(
                                              cornerRadius: 16,
                                              cornerSmoothing: 1.0,
                                            ),
                                          ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // 1. Bill Title / Merchant Name Input
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'ชื่อบิล / รายการ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.inkMuted48,
                                                    ),
                                                  ),
                                                  TextField(
                                                    controller:
                                                        _titleController,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? AppColors.bodyOnDark
                                                          : AppColors.ink,
                                                    ),
                                                    decoration:
                                                        const InputDecoration(
                                                          isDense: true,
                                                          filled: false,
                                                          hintText:
                                                              'เช่น ค่าอาหารมื้อเย็น, ค่าทริป',
                                                          hintStyle: TextStyle(
                                                            fontSize: 14,
                                                            color: AppColors
                                                                .inkMuted48,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                          ),
                                                          border:
                                                              InputBorder.none,
                                                          enabledBorder:
                                                              InputBorder.none,
                                                          focusedBorder:
                                                              InputBorder.none,
                                                          errorBorder:
                                                              InputBorder.none,
                                                          disabledBorder:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              EdgeInsets.only(
                                                                top: 4,
                                                                bottom: 4,
                                                              ),
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
                                        thickness: 1,
                                        color: isDark
                                            ? Colors.white10
                                            : AppColors.hairline,
                                      ),

                                      // 2. Bill Total Amount Input with FinTech Currency Badge
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                '฿',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'ยอดรวมทั้งหมด (บาท)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.inkMuted48,
                                                    ),
                                                  ),
                                                  TextField(
                                                    controller:
                                                        _amountController,
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? AppColors.bodyOnDark
                                                          : AppColors.ink,
                                                    ),
                                                    decoration:
                                                        const InputDecoration(
                                                          isDense: true,
                                                          filled: false,
                                                          hintText: '0.00',
                                                          hintStyle: TextStyle(
                                                            fontSize: 16,
                                                            color: AppColors
                                                                .inkMuted48,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                          ),
                                                          border:
                                                              InputBorder.none,
                                                          enabledBorder:
                                                              InputBorder.none,
                                                          focusedBorder:
                                                              InputBorder.none,
                                                          errorBorder:
                                                              InputBorder.none,
                                                          disabledBorder:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              EdgeInsets.only(
                                                                top: 4,
                                                                bottom: 4,
                                                              ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Section 2: OCR Extracted Items Collapsed Summary Card
                                BillItemsSummaryCard(
                                  items: billState.items,
                                  billTotalAmount: billState.totalAmount,
                                  onItemsUpdated: (newItems) {
                                    ref
                                        .read(billCreationProvider.notifier)
                                        .setItems(newItems);
                                  },
                                ),

                                const SizedBox(height: 20),

                                // Section 3: Friend Selection with Circular '+' and Horizontal Swiper
                                SelectedFriendsHorizontalBar(
                                  allFriends: friends,
                                  selectedParticipants: billState.participants,
                                  onFriendsSelected: (selectedList) {
                                    billNotifier.setSelectedFriends(
                                      selectedList,
                                    );
                                  },
                                  onRemoveParticipant: (userId) {
                                    billNotifier.removeParticipant(userId);
                                  },
                                ),

                                // Section 4: Deterministic Amount Splitting
                                if (billState.participants.isNotEmpty) ...[
                                  const BillSplitEditor(),
                                  const SizedBox(height: 16),
                                ],

                                // Error Display
                                if (billState.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.error.withValues(
                                          alpha: 0.3,
                                        ),
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
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Pinned Bottom Button: Create Bill Button -> Opens Mandatory Confirmation Bottom Sheet
                        ElevatedButton(
                          onPressed:
                              (billState.participants.isEmpty ||
                                  billState.totalAmount <= 0 ||
                                  billState.isSubmitting)
                              ? null
                              : () => _showConfirmationSheet(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            minimumSize: const Size(double.infinity, 50),
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'สร้างบิลและบันทึกหนี้ (Create Bill)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final billState = ref.watch(billCreationProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () async {
              final shouldLeave = await _handleBackNavigation();
              if (shouldLeave && context.mounted) {
                context.pop();
              }
            },
          ),
          const Text(
            'จ่ายเงิน / สร้างบิล',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (billState.hasUnsavedChanges)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'ล้างข้อมูลบิล',
              onPressed: _handleClearBill,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          InkWell(
            onTap: () => setState(() => _currentBottomNavIndex = 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.document_scanner_rounded,
                  color: _currentBottomNavIndex == 0
                      ? AppColors.primary
                      : AppColors.inkMuted48,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  'สแกนบิล OCR',
                  style: TextStyle(
                    fontSize: 12,
                    color: _currentBottomNavIndex == 0
                        ? AppColors.primary
                        : AppColors.inkMuted48,
                    fontWeight: _currentBottomNavIndex == 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _currentBottomNavIndex = 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_card_rounded,
                  color: _currentBottomNavIndex == 1
                      ? AppColors.primary
                      : AppColors.inkMuted48,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  'จ่ายเงิน / สร้างบิล',
                  style: TextStyle(
                    fontSize: 12,
                    color: _currentBottomNavIndex == 1
                        ? AppColors.primary
                        : AppColors.inkMuted48,
                    fontWeight: _currentBottomNavIndex == 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
