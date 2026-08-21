import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/bill_provider.dart';
import '../services/bill_split_calculator.dart';

class BillSplitEditor extends ConsumerWidget {
  const BillSplitEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billState = ref.watch(billCreationProvider);
    final billNotifier = ref.read(billCreationProvider.notifier);
    final authUser = ref.watch(authStateProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ownerSatang = billState.includeOwner
        ? billState.ownerAmountSatang
        : 0;
    final isSumValid = BillSplitCalculator.validateTotalInvariant(
      billState.participants,
      billState.totalSatang,
      ownerSatang: ownerSatang,
    );

    final currentSumSatang =
        billState.participants.fold<int>(
          0,
          (acc, curr) => acc + curr.amountSatang,
        ) +
        ownerSatang;
    final currentSumBaht = BillSplitCalculator.toBaht(currentSumSatang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ส่วนแบ่งรายบุคคล',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: () => billNotifier.rebalanceEvenly(),
              icon: const Icon(Icons.balance_rounded, size: 16),
              label: const Text('หารเท่ากัน', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Owner/Creator Share Deduction Tile with Checkbox
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
            color: billState.includeOwner
                ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.06)
                : (isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment),
            shape: SmoothRectangleBorder(
              side: BorderSide(
                color: billState.includeOwner
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : (isDark ? Colors.white10 : AppColors.hairline),
                width: billState.includeOwner ? 1.5 : 1.0,
              ),
              borderRadius: const SmoothBorderRadius.all(
                SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
              ),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: billState.includeOwner,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                onChanged: (val) {
                  billNotifier.setIncludeOwner(val ?? false);
                },
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  (authUser?.displayName ?? '').isNotEmpty
                      ? (authUser?.displayName ?? '')[0].toUpperCase()
                      : 'ME',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          authUser?.displayName ?? 'ฉัน (เจ้าของหนี้)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark
                                ? AppColors.bodyOnDark
                                : AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ผู้สร้างบิล',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      billState.includeOwner
                          ? 'หักส่วนของตัวเองออกจากบิล'
                          : 'ไม่หักส่วนตัวเอง (หารเฉพาะเพื่อน)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMuted48,
                      ),
                    ),
                  ],
                ),
              ),
              if (billState.includeOwner)
                SizedBox(
                  width: 105,
                  child: TextFormField(
                    initialValue: billState.ownerAmountBaht.toStringAsFixed(2),
                    key: ValueKey(
                      'owner_${billState.ownerAmountSatang}_${billState.includeOwner}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                    decoration: InputDecoration(
                      prefixText: '฿ ',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onFieldSubmitted: (v) {
                      final val = double.tryParse(v);
                      if (val != null) {
                        billNotifier.adjustOwnerAmount(val);
                      }
                    },
                  ),
                )
              else
                const Text(
                  '฿0.00',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMuted48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),

        // Scrollable participants list
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 170),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: billState.participants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final p = billState.participants[idx];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile2 : AppColors.canvas,
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isDark ? Colors.white12 : AppColors.hairline,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        p.displayName.isNotEmpty
                            ? p.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.bodyOnDark
                                  : AppColors.ink,
                            ),
                          ),
                          if (p.isManuallyAdjusted)
                            const Text(
                              'แก้ไขเอง',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 105,
                      child: TextFormField(
                        initialValue: p.amountBaht.toStringAsFixed(2),
                        key: ValueKey('${p.userId}_${p.amountSatang}'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          prefixText: '฿ ',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onFieldSubmitted: (v) {
                          final val = double.tryParse(v);
                          if (val != null) {
                            billNotifier.adjustParticipantAmount(idx, val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Total vs Sum comparison indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSumValid
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSumValid ? '✓ ยอดรวมตรงกันพอดี' : '⚠ ยอดรวมไม่ตรงกับบิล',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSumValid ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                '฿${currentSumBaht.toStringAsFixed(2)} / ฿${billState.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSumValid ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
