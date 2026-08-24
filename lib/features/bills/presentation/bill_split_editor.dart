import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/bill_provider.dart';

class BillSplitEditor extends ConsumerWidget {
  const BillSplitEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billState = ref.watch(billCreationProvider);
    final billNotifier = ref.read(billCreationProvider.notifier);
    final authUser = ref.watch(authStateProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (billState.participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentSumSatang = billState.participants.fold(0, (acc, p) => acc + p.amountSatang) +
        (billState.includeOwner ? billState.ownerAmountSatang : 0);
    final currentSumBaht = currentSumSatang / 100.0;
    final isSumValid = (currentSumSatang - billState.totalSatang).abs() <= 1;
    final isEven = !billState.participants.any((p) => p.isManuallyAdjusted) &&
        !billState.isOwnerAmountManuallyAdjusted;

    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Row: Title & Quick Allocate Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const ShapeDecoration(
                        color: Color(0x1FFF5000),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 8, cornerSmoothing: 0.8),
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Color(0xFFFF5000),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'แบ่งจ่ายค่าบิล (${billState.participants.length + (billState.includeOwner ? 1 : 0)} คน)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: isEven ? null : () => billNotifier.rebalanceEvenly(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEven
                          ? const Color(0xFFFF5000).withValues(alpha: 0.12)
                          : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.balance_rounded,
                          size: 12,
                          color: isEven ? const Color(0xFFFF5000) : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'หารเท่ากัน',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isEven ? const Color(0xFFFF5000) : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),

          // 2. Owner / Creator Share Row (Aligned directly with list)
          InkWell(
            onTap: () {
              billNotifier.setIncludeOwner(!billState.includeOwner);
            },
            child: Container(
              color: billState.includeOwner
                  ? const Color(0xFFFF5000).withValues(alpha: isDark ? 0.08 : 0.03)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  _buildUserAvatar(
                    avatarUrl: authUser?.avatarUrl,
                    displayName: authUser?.displayName ?? 'ฉัน',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                authUser?.displayName ?? 'ฉัน',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ผู้สร้างบิล',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Color(0xFFFF5000),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          billState.includeOwner
                              ? 'มีส่วนฉันในบิลนี้'
                              : 'ไม่คิดส่วนฉัน (หารเฉพาะเพื่อน)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: billState.includeOwner
                          ? const Color(0xFFFF5000).withValues(alpha: 0.12)
                          : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: billState.includeOwner
                            ? const Color(0xFFFF5000).withValues(alpha: 0.3)
                            : Colors.transparent,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      billState.includeOwner
                          ? '฿${billState.ownerAmountBaht.toStringAsFixed(2)}'
                          : 'ไม่หารด้วย',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: billState.includeOwner
                            ? const Color(0xFFFF5000)
                            : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.6,
            indent: 52,
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),

          // 3. Participants List (Straight vertical column alignment)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: billState.participants.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.6,
              indent: 52,
              color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            ),
            itemBuilder: (ctx, idx) {
              final p = billState.participants[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    _buildUserAvatar(
                      avatarUrl: p.avatarUrl,
                      displayName: p.displayName,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p.isManuallyAdjusted) ...[
                            const SizedBox(height: 1),
                            const Text(
                              'แก้ไขยอดเอง',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFF9500),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 96,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceTile3 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                          width: 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: TextFormField(
                        initialValue: p.amountBaht.toStringAsFixed(2),
                        key: ValueKey('${p.userId}_${p.amountSatang}'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                        decoration: const InputDecoration(
                          prefixText: '฿ ',
                          prefixStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF5000),
                          ),
                          isDense: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

          // 4. Compact Summary Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSumValid
                  ? const Color(0xFF34C759).withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSumValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 14,
                      color: isSumValid ? const Color(0xFF34C759) : AppColors.error,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isSumValid ? 'ยอดรวมตรงกันพอดี' : 'ยอดรวมไม่ตรงกับบิล',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: isSumValid ? const Color(0xFF34C759) : AppColors.error,
                      ),
                    ),
                  ],
                ),
                Text(
                  '฿${currentSumBaht.toStringAsFixed(2)} / ฿${billState.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isSumValid ? const Color(0xFF34C759) : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar({
    required String? avatarUrl,
    required String displayName,
    required bool isDark,
  }) {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'U';

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF5000).withValues(alpha: 0.15),
        border: Border.all(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          width: 1.2,
        ),
      ),
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5000),
                      fontSize: 11,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5000),
                    fontSize: 11,
                  ),
                ),
              ),
      ),
    );
  }
}
