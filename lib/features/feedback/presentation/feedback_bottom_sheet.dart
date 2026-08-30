import 'dart:io';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/feedback_model.dart';
import '../providers/feedback_provider.dart';

class FeedbackBottomSheet extends ConsumerStatefulWidget {
  final FeedbackType initialType;

  const FeedbackBottomSheet({
    super.key,
    this.initialType = FeedbackType.bugReport,
  });

  static Future<void> show(
    BuildContext context, {
    FeedbackType initialType = FeedbackType.bugReport,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceBlack : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
            ),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: FeedbackBottomSheet(initialType: initialType),
      ),
    );
  }

  @override
  ConsumerState<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends ConsumerState<FeedbackBottomSheet> {
  late FeedbackType _selectedType;
  FeedbackSeverity _selectedSeverity = FeedbackSeverity.medium;
  int _selectedRating = 5;

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    final authUser = ref.read(authStateProvider).user;
    if (authUser?.email != null && authUser!.email!.trim().isNotEmpty) {
      _emailController.text = authUser.email!.trim();
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _getDeviceInfo() {
    if (kIsWeb) return 'Web Browser (Flutter Web)';
    if (Platform.isIOS) return 'Apple iPhone / iPad (iOS)';
    if (Platform.isAndroid) return 'Android Smartphone (Android)';
    if (Platform.isMacOS) return 'macOS Desktop';
    if (Platform.isWindows) return 'Windows Desktop';
    return 'Unknown Device';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    HapticFeedback.mediumImpact();

    final req = CreateFeedbackRequestModel(
      type: _selectedType,
      subject: _subjectController.text.trim(),
      description: _descriptionController.text.trim(),
      severity: _selectedType == FeedbackType.bugReport ? _selectedSeverity : null,
      rating: _selectedType == FeedbackType.feedback ? _selectedRating : null,
      contactEmail: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      appVersion: 'PingPay Mobile v1.0.0',
      deviceInfo: _getDeviceInfo(),
    );

    final success = await ref
        .read(feedbackNotifierProvider.notifier)
        .submitFeedback(req);

    if (mounted) {
      if (success) {
        AppToast.success(
          context,
          _selectedType == FeedbackType.bugReport
              ? 'ส่งแจ้งปัญหาไปยัง Discord สำเร็จแล้ว ขอบคุณครับ!'
              : 'ส่งข้อเสนอแนะไปยัง Discord สำเร็จแล้ว ขอบคุณครับ!',
        );
        Navigator.of(context).pop();
      } else {
        final err = ref.read(feedbackNotifierProvider).errorMessage ??
            'เกิดข้อผิดพลาดในการส่งข้อมูล กรุณาลองใหม่อีกครั้ง';
        AppToast.error(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(feedbackNotifierProvider);
    final authUser = ref.watch(authStateProvider).user;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Drag handle
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

              // 2. Header with Discord Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: ShapeDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _selectedType.color,
                          _selectedType.color.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    child: Icon(
                      _selectedType.icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              'ส่งข้อเสนอแนะ & แจ้งปัญหา',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: ShapeDecoration(
                                color: const Color(0xFF5865F2).withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: const SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius.all(
                                    SmoothRadius(cornerRadius: 6, cornerSmoothing: 0.6),
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 10, color: Color(0xFF5865F2)),
                                  SizedBox(width: 2),
                                  Text(
                                    'Discord Live',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF5865F2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ข้อความของคุณจะถูกส่งตรงไปยังห้องสนทนาของทีมพัฒนาทันที',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 3. Category Selector Chips
              Text(
                'เลือกประเภทข้อความ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: FeedbackType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedType = type;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: ShapeDecoration(
                            color: isSelected
                                ? type.color.withValues(alpha: isDark ? 0.3 : 0.15)
                                : (isDark ? AppColors.surfaceTile2 : const Color(0xFFF3F4F6)),
                            shape: SmoothRectangleBorder(
                              side: BorderSide(
                                color: isSelected
                                    ? type.color
                                    : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                width: isSelected ? 1.2 : 0.8,
                              ),
                              borderRadius: const SmoothBorderRadius.all(
                                SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type.icon,
                                size: 14,
                                color: isSelected
                                    ? type.color
                                    : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                type.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? Colors.white : type.color)
                                      : (isDark ? AppColors.bodyMuted : AppColors.inkMuted80),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Dynamic Contextual Options (Severity for Bug, Rating for Feedback)
              if (_selectedType == FeedbackType.bugReport) ...[
                Text(
                  'ระดับความรุนแรงของปัญหา',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FeedbackSeverity.values.map((sev) {
                    final isSelected = _selectedSeverity == sev;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedSeverity = sev;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: ShapeDecoration(
                          color: isSelected
                              ? sev.color.withValues(alpha: isDark ? 0.3 : 0.12)
                              : (isDark ? AppColors.surfaceTile2 : const Color(0xFFF3F4F6)),
                          shape: SmoothRectangleBorder(
                            side: BorderSide(
                              color: isSelected ? sev.color : Colors.transparent,
                              width: 1,
                            ),
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                            ),
                          ),
                        ),
                        child: Text(
                          sev.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? sev.color
                                : (isDark ? AppColors.bodyMuted : AppColors.inkMuted80),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ] else if (_selectedType == FeedbackType.feedback) ...[
                Text(
                  'คะแนนความพึงพอใจต่อ PingPay',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    final starNum = i + 1;
                    final isFilled = starNum <= _selectedRating;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedRating = starNum;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFilled ? const Color(0xFFFFB800) : AppColors.inkMuted48,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Subject Input
              Text(
                'หัวข้อข้อความ *',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF9FAFB),
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                      width: 0.9,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: TextFormField(
                  controller: _subjectController,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedType == FeedbackType.bugReport
                        ? 'เช่น หน้าสแกนสลิปแจ้งว่าสลิปซ้ำ'
                        : 'เช่น อยากให้เพิ่มตัวเลือกแบ่งเงิน...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'กรุณาระบุหัวข้ออย่างน้อย 2 ตัวอักษร';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 6. Description Input
              Text(
                'รายละเอียด *',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF9FAFB),
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                      width: 0.9,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  minLines: 3,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: 'อธิบายปัญหาที่พบ ขั้นตอนที่ทำให้เกิดข้อผิดพลาด หรือข้อเสนอแนะของคุณอย่างละเอียด...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 5) {
                      return 'กรุณาระบุรายละเอียดอย่างน้อย 5 ตัวอักษร';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 7. Contact Info (Auto-filled from Google / Auth Account)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'อีเมลสำหรับติดต่อกลับ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                  ),
                  if (authUser?.email != null && authUser!.email!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 6, cornerSmoothing: 0.6),
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF10B981)),
                          SizedBox(width: 3),
                          Text(
                            'ดึงจากบัญชีอัตโนมัติ',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF9FAFB),
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                      width: 0.9,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'เช่น yourname@example.com',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      size: 16,
                      color: AppColors.inkMuted48,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 8. Diagnostics Info Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: ShapeDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF3F4F6),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.6),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ระบบจะแนบข้อมูล PingPay v1.0.0 (${_getDeviceInfo()}) อัตโนมัติเพื่อช่วยทีมงานวิเคราะห์ปัญหา',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 9. Submit Button
              AppButton(
                text: 'ส่งข้อความไปยัง Discord',
                icon: Icons.send_rounded,
                isLoading: state.isLoading,
                onPressed: state.isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
