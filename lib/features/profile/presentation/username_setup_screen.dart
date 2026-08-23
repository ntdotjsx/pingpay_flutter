import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/input_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/providers/auth_provider.dart';

class UsernameSetupScreen extends ConsumerStatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  ConsumerState<UsernameSetupScreen> createState() =>
      _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends ConsumerState<UsernameSetupScreen> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    if (user != null) {
      _usernameController.text = user.displayName ?? '';
      _fullNameController.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref
          .read(authStateProvider.notifier)
          .completeProfile(
            _fullNameController.text.trim(),
            displayName: _usernameController.text.trim(),
          );
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFFAFBFD),
      appBar: AppBar(
        title: const Text(
          'ตั้งค่าข้อมูลโปรไฟล์',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A00), Color(0xFFFF5000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.35 : 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceTile1 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 42,
                          color: Color(0xFFFF5000),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'ขั้นตอนสุดท้าย: ตั้งชื่อบัญชีของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ชื่อนี้จะใช้แสดงบนรายการบิลและให้เพื่อนค้นหา',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                ),
                const SizedBox(height: 28),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile1 : Colors.white,
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
                      ),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'ชื่อที่แสดง / ชื่อเล่น (Display Name / Username)',
                        hint: 'เช่น นัท ธนพล หรือ Nut',
                        controller: _usernameController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFFF5000)),
                        validator: (v) => InputValidators.validateRequired(
                          v,
                          fieldName: 'ชื่อที่แสดง',
                          minLength: 2,
                          maxLength: 50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'ชื่อ-นามสกุลจริง (Full Name)',
                        hint: 'เช่น นายธนพล สุขใจ',
                        controller: _fullNameController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFFFF5000)),
                        validator: (v) => InputValidators.validateRequired(
                          v,
                          fieldName: 'ชื่อ-นามสกุลจริง',
                          minLength: 3,
                          maxLength: 100,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                AppButton(
                  text: 'เสร็จสิ้นและเริ่มใช้งาน',
                  isLoading: authState.isLoading,
                  icon: Icons.check_circle_outline,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
