import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/thai_banks.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/input_validators.dart';
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
  final _realNameController = TextEditingController();
  final _promptPayController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _trueMoneyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  ThaiBank? _selectedBank;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    if (user != null) {
      _realNameController.text = user.fullName ?? '';
      _promptPayController.text = user.promptPayId ?? user.phoneNumber ?? '';
      _bankAccountController.text = user.bankAccountNumber ?? '';
      _trueMoneyController.text = user.truemoneyPhone ?? '';

      if (user.bankCode != null && user.bankCode!.isNotEmpty) {
        try {
          _selectedBank = kThaiBanks.firstWhere(
            (b) => b.code.toLowerCase() == user.bankCode!.toLowerCase(),
          );
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _realNameController.dispose();
    _promptPayController.dispose();
    _bankAccountController.dispose();
    _trueMoneyController.dispose();
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

    final realName = _realNameController.text.trim();
    final promptPay = _promptPayController.text.trim();
    final trueMoney = _trueMoneyController.text.trim();
    final bankAccount = _bankAccountController.text.trim();

    if (promptPay.isEmpty && bankAccount.isEmpty && trueMoney.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณาระบุอย่างน้อย 1 ช่องทางสำหรับรับเงิน (พร้อมเพย์, บัญชีธนาคาร หรือ TrueMoney)';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authStateProvider).user;

      // Extract first & last name from realName
      final nameWords = realName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final firstName = nameWords.isNotEmpty ? nameWords.first : null;
      final lastName = nameWords.length > 1 ? nameWords.sublist(1).join(' ') : null;

      String? promptPayType;
      if (promptPay.isNotEmpty) {
        final cleanPP = promptPay.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPP.length == 13) {
          promptPayType = 'national_id';
        } else if (cleanPP.length == 15) {
          promptPayType = 'ewallet_id';
        } else {
          promptPayType = 'mobile_number';
        }
      }

      await ref.read(authStateProvider.notifier).completeProfile(
        realName,
        displayName: user?.displayName,
        firstName: firstName,
        lastName: lastName,
        phone: promptPay.isNotEmpty ? promptPay : user?.phoneNumber,
        promptPayId: promptPay.isNotEmpty ? promptPay : null,
        promptPayIdType: promptPayType,
        bankAccountNumber: bankAccount.isNotEmpty ? bankAccount : null,
        bankName: _selectedBank?.name,
        bankCode: _selectedBank?.code,
        truemoneyPhone: trueMoney.isNotEmpty ? trueMoney : null,
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.only(
              topLeft: SmoothRadius(cornerRadius: 28, cornerSmoothing: 1.0),
              topRight: SmoothRadius(cornerRadius: 28, cornerSmoothing: 1.0),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Badge & Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ตั้งค่าช่องทางรับชำระเงิน',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ระบุชื่อจริงและช่องทางรับเงินเพื่อให้ EasySlip ตรวจสลิปได้ถูกต้อง',
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
                ],
              ),

              const SizedBox(height: 16),

              // ── 1. Real Name Field ─────────────────────────────────────
              AppTextField(
                label: 'ชื่อ - นามสกุลจริง (สำหรับตรวจสลิป EasySlip) *',
                hint: 'เช่น ธนพล พรหมมาศ หรือ Thanapon Phorarmat',
                controller: _realNameController,
                keyboardType: TextInputType.name,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                prefixIcon: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                ),
                validator: (v) => InputValidators.validateRealName(v, required: true),
              ),

              const SizedBox(height: 14),

              // ── 2. PromptPay Field ─────────────────────────────────────
              AppTextField(
                label: 'เบอร์พร้อมเพย์ / เลขบัตร ปชช. / e-Wallet *',
                hint: 'เช่น 0826419844 หรือ 1100501234567',
                controller: _promptPayController,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                prefixIcon: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xFF003D6B),
                ),
                validator: (v) => InputValidators.validatePromptPay(v, required: false),
              ),

              const SizedBox(height: 14),

              // ── 3. Bank Account Selection Tile ─────────────────────────
              Text(
                'ธนาคารสำหรับรับเงินโอนตรง (ไม่บังคับ)',
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
                          size: 22,
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

              const SizedBox(height: 12),

              // Bank Account Number Field
              AppTextField(
                label: 'เลขบัญชีธนาคาร (ไม่บังคับ)',
                hint: 'เช่น 1234567890 (ตัวเลข 10-12 หลัก)',
                controller: _bankAccountController,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                prefixIcon: const Icon(
                  Icons.numbers_rounded,
                  color: Colors.blueGrey,
                ),
                validator: (v) {
                  if (_selectedBank != null && (v == null || v.trim().isEmpty)) {
                    return 'กรุณาระบุเลขบัญชีเมื่อเลือกธนาคาร';
                  }
                  return InputValidators.validateBankAccount(v, required: false);
                },
              ),

              const SizedBox(height: 14),

              // ── 4. TrueMoney Wallet Field ──────────────────────────────
              AppTextField(
                label: 'เบอร์ TrueMoney Wallet (ไม่บังคับ)',
                hint: 'เช่น 0826419844 (เบอร์โทร 10 หลัก)',
                controller: _trueMoneyController,
                keyboardType: TextInputType.phone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                prefixIcon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFFFF8200),
                ),
                validator: (v) => InputValidators.validatePhoneNumber(v, required: false),
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

              const SizedBox(height: 20),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
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
                            'บันทึกช่องทางรับเงิน',
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
