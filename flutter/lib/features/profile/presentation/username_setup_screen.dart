import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_toast.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าข้อมูลโปรไฟล์'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_circle_outlined,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'ขั้นตอนสุดท้าย: ตั้งชื่อบัญชีของคุณ',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ชื่อนี้จะใช้แสดงในกลุ่มและบนรายการบิลหารเงินกับเพื่อน',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),

                AppTextField(
                  label: 'ชื่อที่แสดง / ชื่อเล่น (Display Name / Username)',
                  hint: 'เช่น นัท ธนพล หรือ Nut',
                  controller: _usernameController,
                  prefixIcon: const Icon(Icons.person_outline),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'กรุณาระบุชื่อที่แสดง'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'ชื่อ-นามสกุลจริง (Full Name)',
                  hint: 'เช่น นายธนพล สุขใจ',
                  controller: _fullNameController,
                  prefixIcon: const Icon(Icons.badge_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'กรุณาระบุชื่อ-นามสกุลจริง'
                      : null,
                ),
                const SizedBox(height: AppSpacing.xxl),

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
