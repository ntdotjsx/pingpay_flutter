import 'dart:async';
import 'dart:io';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ocr_models.dart';
import '../providers/ocr_provider.dart';

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen>
    with SingleTickerProviderStateMixin {
  int _currentBottomNavIndex = 1; // 0 = สแกนบิล OCR, 1 = สร้างบิล / จัดการเงิน
  int _cardTopTabIndex = 1; // 0 = สแกน QR / จ่ายเงิน, 1 = สร้างบิลหารเงิน

  // Bill Form state
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  int _selectedSourceIndex = 0;
  final ImagePicker _picker = ImagePicker();

  // Scanner animation
  late AnimationController _scannerAnimController;
  late Animation<double> _scannerAnimation;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scannerAnimController.dispose();
    _titleController.dispose();
    _amountController.dispose();
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

      final result = await ref.read(ocrScanProvider.notifier).scanReceipt(file);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (result != null) {
        _populateBillFromOcr(result);
      } else {
        final err = ref.read(ocrScanProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'ไม่สามารถดึงข้อมูลจากรูปภาพได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
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
              CircularProgressIndicator(color: Color(0xFFFF5000)),
              SizedBox(height: 20),
              Text(
                'กำลังประมวลผล OCR ใบเสร็จ...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                'ระบบกำลังวิเคราะห์ร้านค้า รายการ และยอดรวม',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _populateBillFromOcr(ReceiptOcrResultModel receipt) {
    setState(() {
      _currentBottomNavIndex = 1; // switch to create bill tab
      _cardTopTabIndex = 1;
      _titleController.text = receipt.merchant;
      _amountController.text = receipt.totalAmount.toStringAsFixed(2);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ดึงข้อมูลจาก "${receipt.merchant}" ยอด ฿${receipt.totalAmount.toStringAsFixed(2)} เรียบร้อย',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: _currentBottomNavIndex == 0
          ? Colors.black
          : const Color(0xFFFF5000),
      body: _currentBottomNavIndex == 0
          ? _buildCameraOcrScannerView()
          : _buildPaymentCreateBillView(user),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ==========================================
  // VIEW 1: FULL CAMERA OCR SCANNER VIEW
  // ==========================================
  Widget _buildCameraOcrScannerView() {
    return Stack(
      children: [
        // Camera Viewport Simulation Background
        Positioned.fill(
          child: Container(
            color: const Color(0xFF101012),
            child: Center(
              child: Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),

        // Dark Vignette Overlay
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
              // Top Bar (Back button, Title, Torch flashlight toggle)
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

              // Top Prompt Pills (รองรับพร้อมเพย์ / บิลใบเสร็จทุกประเภท)
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

              // Center Scanning Target Box with Glowing Animated Laser Line
              Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // 4 Corner Brackets
                    Positioned(
                      top: -1,
                      left: -1,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFFF5000), width: 4),
                            left: BorderSide(
                              color: Color(0xFFFF5000),
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFFF5000), width: 4),
                            right: BorderSide(
                              color: Color(0xFFFF5000),
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      left: -1,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFFF5000),
                              width: 4,
                            ),
                            left: BorderSide(
                              color: Color(0xFFFF5000),
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      right: -1,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFFF5000),
                              width: 4,
                            ),
                            right: BorderSide(
                              color: Color(0xFFFF5000),
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Animated Glowing Orange Laser Line
                    AnimatedBuilder(
                      animation: _scannerAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _scannerAnimation.value * 260 + 10,
                          left: 15,
                          right: 15,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color(0xFFFF8500),
                                  Color(0xFFFF3B30),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF5000,
                                  ).withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'วางบิลหรือใบเสร็จให้อยู่ในกรอบ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              // Bottom Action: Take Photo & Pick from Gallery
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Button
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

                    // Shutter Button
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: const Color(0xFFFF5000),
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
  // VIEW 2: CREATE BILL & PAYMENT VIEW
  // ==========================================
  Widget _buildPaymentCreateBillView(dynamic user) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE53935),
                  Color(0xFFFF5000),
                  Color(0xFFFF6A00),
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
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
                      'จ่ายเงิน / สร้างบิล',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Main Scrolling Form Card
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // White Card
                      Container(
                        width: double.infinity,
                        decoration: const ShapeDecoration(
                          color: Colors.white,
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 24,
                                cornerSmoothing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        child: Column(
                          children: [
                            // Segmented Tabs: [ จ่ายเงิน ] | [ สร้างบิล ]
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F3F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  // Tab 0: จ่ายเงิน
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _cardTopTabIndex = 0),
                                      child: Container(
                                        height: 36,
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: _cardTopTabIndex == 0
                                              ? Colors.white
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          boxShadow: _cardTopTabIndex == 0
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
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
                                                ? const Color(0xFFE53935)
                                                : const Color(0xFF666666),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Tab 1: สร้างบิล
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _cardTopTabIndex = 1),
                                      child: Container(
                                        height: 36,
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: _cardTopTabIndex == 1
                                              ? Colors.white
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          boxShadow: _cardTopTabIndex == 1
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
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
                                                ? const Color(0xFFE53935)
                                                : const Color(0xFF666666),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Card Brand Header
                            const Row(
                              children: [
                                Text(
                                  'ping',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFF5000),
                                  ),
                                ),
                                Text(
                                  'pay',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Bill Form Inputs
                            TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'ชื่อบิล / รายการ',
                                hintText: 'เช่น ค่าอาหารมื้อเย็น, ค่าทริป',
                                prefixIcon: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFFFF5000),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'ยอดรวมทั้งหมด (บาท)',
                                hintText: '0.00',
                                prefixIcon: const Icon(
                                  Icons.attach_money_rounded,
                                  color: Color(0xFFFF5000),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ช่องทางชำระเงิน Section
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'ช่องทางชำระเงินเริ่มต้น',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Horizontal Payment Source Cards
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildPaymentSourceCard(
                                    index: 0,
                                    icon: Icons.account_balance_wallet_rounded,
                                    iconColor: const Color(0xFFFF5000),
                                    title: 'วอลเล็ท',
                                    subtitle: 'ยอดเงินคงเหลือ',
                                    amount: '฿ 1,250.00',
                                    isSelected: _selectedSourceIndex == 0,
                                    onTap: () => setState(
                                      () => _selectedSourceIndex = 0,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildPaymentSourceCard(
                                    index: 1,
                                    icon: Icons.account_balance_rounded,
                                    iconColor: const Color(0xFF107C41),
                                    title: 'กสิกรไทย',
                                    subtitle: 'พร้อมใช้งาน',
                                    amount: '***6489',
                                    isSelected: _selectedSourceIndex == 1,
                                    onTap: () => setState(
                                      () => _selectedSourceIndex = 1,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildPaymentSourceCard(
                                    index: 2,
                                    icon: Icons.savings_rounded,
                                    iconColor: const Color(0xFF1E3A8A),
                                    title: 'KKP Saving',
                                    subtitle: 'ดอกเบี้ยสูง 2%',
                                    amount: null,
                                    isSelected: _selectedSourceIndex == 2,
                                    onTap: () => setState(
                                      () => _selectedSourceIndex = 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button
                            ElevatedButton(
                              onPressed: () {
                                final title = _titleController.text.trim();
                                final amount = double.tryParse(
                                  _amountController.text.trim(),
                                );

                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('กรุณากรอกชื่อบิล'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                if (amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'กรุณากรอกจำนวนเงินให้ถูกต้อง',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'สร้างบิล "$title" ยอด ฿$amount สำเร็จ!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5000),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'บันทึกและเลือกเพื่อนเพื่อหารบิล',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSourceCard({
    required int index,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String? amount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 105,
        height: 100,
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: isSelected ? const Color(0xFFFFF7F2) : const Color(0xFFF9FAFB),
          shape: SmoothRectangleBorder(
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFFFF6A00)
                  : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: const SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: iconColor, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D1D1F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF888888)),
                ),
                if (amount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFFFF5000)
                          : const Color(0xFF1D1D1F),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM 2-TAB BAR
  // ==========================================
  Widget _buildBottomNavigationBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // TAB 0: สแกนบิล OCR
          InkWell(
            onTap: () => setState(() => _currentBottomNavIndex = 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.document_scanner_rounded,
                  color: _currentBottomNavIndex == 0
                      ? const Color(0xFFFF5000)
                      : const Color(0xFF888888),
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  'สแกนบิล OCR',
                  style: TextStyle(
                    fontSize: 12,
                    color: _currentBottomNavIndex == 0
                        ? const Color(0xFFFF5000)
                        : const Color(0xFF888888),
                    fontWeight: _currentBottomNavIndex == 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          // TAB 1: จ่ายเงิน / สร้างบิล
          InkWell(
            onTap: () => setState(() => _currentBottomNavIndex = 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_card_rounded,
                  color: _currentBottomNavIndex == 1
                      ? const Color(0xFFFF5000)
                      : const Color(0xFF888888),
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  'จ่ายเงิน / สร้างบิล',
                  style: TextStyle(
                    fontSize: 12,
                    color: _currentBottomNavIndex == 1
                        ? const Color(0xFFFF5000)
                        : const Color(0xFF888888),
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
