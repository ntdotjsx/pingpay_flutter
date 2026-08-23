import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../models/friend_models.dart';
import '../providers/friends_provider.dart';

class QrScanFriendScreen extends ConsumerStatefulWidget {
  const QrScanFriendScreen({super.key});

  @override
  ConsumerState<QrScanFriendScreen> createState() => _QrScanFriendScreenState();
}

class _QrScanFriendScreenState extends ConsumerState<QrScanFriendScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _laserAnimation;
  late final Animation<double> _pulseAnimation;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  List<Offset>? _detectedCorners;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  String? _extractUserCode(String raw) {
    final trimmed = raw.trim();
    // 1. Direct match: USR-XXXXXX
    final directMatch = RegExp(r'USR-[A-Za-z0-9]+', caseSensitive: false).firstMatch(trimmed);
    if (directMatch != null) {
      return directMatch.group(0)!.toUpperCase();
    }
    // 2. URI parameters: ?code=USR-XXXX or /friend/USR-XXXX
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final codeParam = uri.queryParameters['code'] ?? uri.queryParameters['userCode'];
      if (codeParam != null && codeParam.isNotEmpty) {
        return codeParam.toUpperCase();
      }
      final pathSegments = uri.pathSegments;
      for (final seg in pathSegments) {
        if (seg.toUpperCase().startsWith('USR-')) {
          return seg.toUpperCase();
        }
      }
    }
    return null;
  }

  Future<void> _handleScannedCode(String rawValue, {List<Offset>? corners}) async {
    if (_isProcessing) return;

    final userCode = _extractUserCode(rawValue);
    if (userCode == null) {
      // Not a valid PingPay friend QR code
      AppToast.warning(context, 'QR Code นี้ไม่ใช่รหัสเพื่อนของ PingPay');
      return;
    }

    setState(() {
      _isProcessing = true;
      _detectedCorners = corners;
    });

    HapticFeedback.heavyImpact();

    try {
      final repo = ref.read(friendsRepositoryProvider);
      final user = await repo.searchUser(userCode);

      if (!mounted) return;

      if (user == null) {
        AppToast.error(context, 'ไม่พบข้อมูลผู้ใช้สำหรับรหัส $userCode');
        setState(() {
          _isProcessing = false;
          _detectedCorners = null;
        });
        return;
      }

      await _showFriendFoundBottomSheet(user);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'เกิดข้อผิดพลาดในการค้นหาผู้ใช้: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _detectedCorners = null;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final barcodes = await _controller.analyzeImage(image.path);
    if (barcodes != null && barcodes.barcodes.isNotEmpty) {
      final first = barcodes.barcodes.first;
      if (first.rawValue != null) {
        await _handleScannedCode(first.rawValue!, corners: first.corners);
        return;
      }
    }

    if (mounted) {
      AppToast.warning(context, 'ไม่พบ QR Code ในรูปภาพที่เลือก');
    }
  }

  Future<void> _showFriendFoundBottomSheet(UserSearchModel user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final actionState = ref.watch(friendActionsProvider);

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceBlack : Colors.white,
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.vertical(
                    top: SmoothRadius(cornerRadius: 32, cornerSmoothing: 0.7),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle Bar
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Friend Success Icon Badge
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFFFF5000),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'ตรวจพบผู้ใช้งาน PingPay 🎉',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'พบข้อมูลโปรไฟล์จาก QR Code ที่สแกน',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Friend Profile Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: ShapeDecoration(
                      color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF7F8FA),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // User Avatar
                        Container(
                          width: 58,
                          height: 58,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFFF5000).withValues(alpha: 0.15),
                            shape: const SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius.all(
                                SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.6),
                              ),
                            ),
                          ),
                          child: ClipSmoothRect(
                            radius: const SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.6),
                            ),
                            child: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                ? Image.network(
                                    user.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        user.displayName.isNotEmpty
                                            ? user.displayName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF5000),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      user.displayName.isNotEmpty
                                          ? user.displayName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF5000),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  user.userCode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: Color(0xFFFF5000),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: actionState.isLoading
                          ? null
                          : () async {
                              final success = await ref
                                  .read(friendActionsProvider.notifier)
                                  .sendRequest(user.userCode);
                              if (success && sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                                if (context.mounted) {
                                  AppToast.success(context, 'ส่งคำขอเป็นเพื่อนเรียบร้อยแล้ว 🎉');
                                  context.pop(); // Return to friends screen
                                }
                              }
                            },
                      icon: actionState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: Text(
                        actionState.isLoading ? 'กำลังส่งคำขอ...' : 'ส่งคำขอเป็นเพื่อน',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5000),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: Text(
                        'สแกนรหัสอื่นต่อ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanBoxSize = screenSize.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Mobile Camera Viewport
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !_isProcessing) {
                final barcode = barcodes.first;
                if (barcode.rawValue != null) {
                  _handleScannedCode(barcode.rawValue!, corners: barcode.corners);
                }
              }
            },
          ),

          // 2. Translucent Cutout Shading Layer
          CustomPaint(
            size: screenSize,
            painter: _ScannerOverlayPainter(
              scanBoxSize: scanBoxSize,
              borderColor: Colors.transparent,
            ),
          ),

          // 3. Central Animated QR Target Reticle & Laser Sweep
          Center(
            child: SizedBox(
              width: scanBoxSize,
              height: scanBoxSize,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Pulsing Corner Brackets
                      Transform.scale(
                        scale: _pulseAnimation.value,
                        child: CustomPaint(
                          size: Size(scanBoxSize, scanBoxSize),
                          painter: _ReticleCornerPainter(
                            cornerColor: const Color(0xFFFF5000),
                            strokeWidth: 4.5,
                            cornerLength: 32.0,
                          ),
                        ),
                      ),

                      // Animated Laser Beam Sweep
                      Positioned(
                        top: _laserAnimation.value * (scanBoxSize - 20),
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF5000).withValues(alpha: 0.0),
                                const Color(0xFFFF5000),
                                const Color(0xFFFF9400),
                                const Color(0xFFFF5000),
                                const Color(0xFFFF5000).withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5000).withValues(alpha: 0.8),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 4. Top Glass Navigation Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  _buildGlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop(),
                  ),

                  // Title Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_rounded, color: Color(0xFFFF5000), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'สแกน QR เพิ่มเพื่อน',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Flashlight & Camera Switch Buttons
                  Row(
                    children: [
                      _buildGlassButton(
                        icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        iconColor: _isTorchOn ? const Color(0xFFFFD700) : Colors.white,
                        onTap: () async {
                          await _controller.toggleTorch();
                          setState(() {
                            _isTorchOn = !_isTorchOn;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildGlassButton(
                        icon: Icons.cameraswitch_rounded,
                        onTap: () async {
                          await _controller.switchCamera();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Instructions & Gallery Button
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Instruction Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.center_focus_strong_rounded, color: Color(0xFFFF5000), size: 18),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'วาง QR Code ให้อยู่ในกรอบเพื่อตรวจจับอัตโนมัติ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Pick from Gallery Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text(
                      'เลือกรูป QR Code จากคลังภาพ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

/// Custom painter for dimmed overlay with clear cutout in center
class _ScannerOverlayPainter extends CustomPainter {
  final double scanBoxSize;
  final Color borderColor;

  _ScannerOverlayPainter({
    required this.scanBoxSize,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanBoxSize,
      height: scanBoxSize,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.scanBoxSize != scanBoxSize;
}

/// Custom painter for glowing corner reticles around scan frame
class _ReticleCornerPainter extends CustomPainter {
  final Color cornerColor;
  final double strokeWidth;
  final double cornerLength;

  _ReticleCornerPainter({
    required this.cornerColor,
    required this.strokeWidth,
    required this.cornerLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final radius = 22.0;
    final w = size.width;
    final h = size.height;

    // Top-Left Corner
    final tlPath = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..lineTo(cornerLength, 0);
    canvas.drawPath(tlPath, paint);

    // Top-Right Corner
    final trPath = Path()
      ..moveTo(w - cornerLength, 0)
      ..lineTo(w - radius, 0)
      ..arcToPoint(Offset(w, radius), radius: Radius.circular(radius))
      ..lineTo(w, cornerLength);
    canvas.drawPath(trPath, paint);

    // Bottom-Left Corner
    final blPath = Path()
      ..moveTo(0, h - cornerLength)
      ..lineTo(0, h - radius)
      ..arcToPoint(Offset(radius, h), radius: Radius.circular(radius))
      ..lineTo(cornerLength, h);
    canvas.drawPath(blPath, paint);

    // Bottom-Right Corner
    final brPath = Path()
      ..moveTo(w - cornerLength, h)
      ..lineTo(w - radius, h)
      ..arcToPoint(Offset(w, h - radius), radius: Radius.circular(radius))
      ..lineTo(w, h - cornerLength);
    canvas.drawPath(brPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ReticleCornerPainter oldDelegate) => false;
}
