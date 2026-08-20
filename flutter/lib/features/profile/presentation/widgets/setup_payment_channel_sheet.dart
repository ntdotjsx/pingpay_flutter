import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/thai_banks.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/providers/auth_provider.dart';

class SetupPaymentChannelSheet extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;

  const SetupPaymentChannelSheet({super.key, this.onSaved});

  static Future<bool?> show(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SetupPaymentChannelSheet(onSaved: onSaved),
    );
  }

  @override
  ConsumerState<SetupPaymentChannelSheet> createState() =>
      _SetupPaymentChannelSheetState();
}

class _SetupPaymentChannelSheetState
    extends ConsumerState<SetupPaymentChannelSheet> {
  final _promptPayController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  ThaiBank? _selectedBank;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    if (user != null) {
      _promptPayController.text = user.promptPayId ?? user.phoneNumber ?? '';
      _bankAccountController.text = user.bankAccountNumber ?? '';
    }
  }

  @override
  void dispose() {
    _promptPayController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  void _showBankPicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.only(
              topLeft: SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
              topRight: SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'เลือกธนาคาร',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: kThaiBanks.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : AppColors.dividerSoft,
                ),
                itemBuilder: (context, index) {
                  final bank = kThaiBanks[index];
                  final isSelected = _selectedBank?.code == bank.code;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: _buildBankLogoBadge(bank, size: 38),
                    title: Text(
                      bank.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.bodyOnDark : AppColors.ink),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedBank = bank);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankLogoBadge(ThaiBank bank, {double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bank.color,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: bank.color.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        bank.logoCode,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final promptPay = _promptPayController.text.trim();
    if (promptPay.isEmpty) {
      setState(() {
        _errorMessage =
            'กรุณาระบุเบอร์พร้อมเพย์หรือเลขบัตรประชาชนสำหรับรับเงิน';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authStateProvider).user;
      final bankAccount = _bankAccountController.text.trim();
      final formattedBankAccount = _selectedBank != null && bankAccount.isNotEmpty
          ? '${_selectedBank!.shortName} $bankAccount'
          : (bankAccount.isNotEmpty ? bankAccount : null);

      await ref.read(authStateProvider.notifier).completeProfile(
        user?.fullName ?? user?.displayName ?? 'User',
        displayName: user?.displayName,
        phone: promptPay,
        bankAccountNumber: formattedBankAccount,
      );

      if (mounted) {
        Navigator.pop(context, true);
        widget.onSaved?.call();
        AppToast.success(context, 'บันทึกช่องทางรับเงินเรียบร้อยแล้ว');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.only(
              topLeft: SmoothRadius(cornerRadius: 28, cornerSmoothing: 1.0),
              topRight: SmoothRadius(cornerRadius: 28, cornerSmoothing: 1.0),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Badge & Title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ตั้งค่าช่องทางชำระเงิน',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ต้องตั้งค่าพร้อมเพย์ก่อนสร้างบิลหรือสแกน OCR เพื่อให้เพื่อนโอนเงินคืนคุณได้',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // PromptPay Field
              AppTextField(
                label: 'เบอร์พร้อมเพย์ หรือ เลขบัตรประชาชน *',
                hint: 'เช่น 0812345678 หรือ 1100501234567',
                controller: _promptPayController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.primary,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'กรุณาระบุเบอร์พร้อมเพย์';
                  }
                  final clean = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (clean.length != 10 &&
                      clean.length != 13 &&
                      clean.length != 15) {
                    return 'พร้อมเพย์ต้องเป็นเบอร์โทร 10 หลัก หรือเลขบัตร 13 หลัก';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Bank Selection Tile with Logo
              Text(
                'เลือกธนาคาร (สำหรับรับเงินโอนตรง)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showBankPicker(context, isDark),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceTile2
                        : AppColors.canvasParchment,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white10 : AppColors.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_selectedBank != null) ...[
                        _buildBankLogoBadge(_selectedBank!, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedBank!.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.bodyOnDark
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.account_balance_rounded,
                          size: 24,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'แตะเพื่อเลือกธนาคาร',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.inkMuted48,
                            ),
                          ),
                        ),
                      ],
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.inkMuted48,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Bank Account Number Field
              AppTextField(
                label: 'เลขบัญชีธนาคาร (ไม่บังคับ)',
                hint: 'เช่น 123-4-56789-0',
                controller: _bankAccountController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(
                  Icons.numbers_rounded,
                  color: Colors.blueGrey,
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
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
                          Icon(Icons.check_circle_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'บันทึกและเริ่มสร้างบิล',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ไว้ตั้งค่าภายหลัง'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

