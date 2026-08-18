import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/providers/auth_provider.dart';

class PdpaScreen extends ConsumerStatefulWidget {
  const PdpaScreen({super.key});

  @override
  ConsumerState<PdpaScreen> createState() => _PdpaScreenState();
}

class _PdpaScreenState extends ConsumerState<PdpaScreen> {
  bool _hasConsent = false;

  Future<void> _handleAccept() async {
    if (!_hasConsent) return;
    try {
      await ref.read(authStateProvider.notifier).acceptPdpa();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('นโยบายความเป็นส่วนตัว (PDPA)'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: AppRadius.roundedMd,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ข้อตกลงและเงื่อนไขการใช้งานข้อมูลส่วนบุคคล',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'เวอร์ชันนโยบาย: v1.0.0',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Divider(height: 24),
                        Text(
                          '1. การเก็บรวบรวมข้อมูลส่วนบุคคล\n'
                          'แอปพลิเคชัน PingPay จะเก็บรวบรวมข้อมูลบัญชีผู้ใช้, ข้อมูลการหารค่าใช้จ่าย (บิล), ประวัติการโอนเงินและสลิปการชำระเงิน เพื่อวัตถุประสงค์ในการคำนวณยอดหนี้และส่งการแจ้งเตือนเท่านั้น\n\n'
                          '2. ความปลอดภัยของข้อมูลการเงิน\n'
                          'ข้อมูลสลิปและรายการทางการเงินทั้งหมดจะถูกตรวจสอบผ่านระบบเข้ารหัสที่ปลอดภัย และไม่มีการนำข้อมูลส่วนตัวของท่านไปเปิดเผยต่อบุคคลภายนอกที่ไม่เกี่ยวข้อง\n\n'
                          '3. สิทธิของเจ้าของข้อมูลส่วนบุคคล\n'
                          'ท่านสามารถขอลบหรือระงับการประมวลผลข้อมูลของท่านได้ตลอดเวลาผ่านการตั้งค่าบัญชีในแอปพลิเคชัน',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () {
                  setState(() {
                    _hasConsent = !_hasConsent;
                  });
                },
                borderRadius: AppRadius.roundedSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _hasConsent,
                        onChanged: (v) {
                          setState(() {
                            _hasConsent = v ?? false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ข้าพเจ้าได้อ่านและยินยอมให้ประมวลผลข้อมูลส่วนบุคคลตามนโยบายความเป็นส่วนตัวข้างต้น',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: 'ยอมรับและดำเนินการต่อ',
                isLoading: authState.isLoading,
                onPressed: _hasConsent ? _handleAccept : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
