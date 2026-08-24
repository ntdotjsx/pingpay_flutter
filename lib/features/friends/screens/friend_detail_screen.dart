import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/pingpay_loading.dart';
import '../../../core/utils/app_toast.dart';
import '../../bills/providers/bill_provider.dart';
import '../../payments/services/debt_age_calculator.dart';
import '../models/friend_models.dart';
import '../providers/friends_provider.dart';

class FriendDetailScreen extends ConsumerWidget {
  final String friendshipId;

  const FriendDetailScreen({super.key, required this.friendshipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendAsync = ref.watch(friendDetailProvider(friendshipId));
    final removalCheckAsync = ref.watch(removalCheckProvider(friendshipId));
    final actionState = ref.watch(friendActionsProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceBlack
          : const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text(
          'ข้อมูลเพื่อน',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF6F8FB),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: friendAsync.when(
        loading: () => const PingPayLoadingWidget(size: 120),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_off_rounded,
                    size: 40,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ไม่พบข้อมูลเพื่อนหรือถูกลบไปแล้ว',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'รายการนี้อาจถูกยกเลิกหรือไม่มีอยู่ในระบบอีกต่อไป',
                  style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted48),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('กลับไปยังรายชื่อเพื่อน', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (friend) {
          final friendsSinceDateStr = DebtAgeCalculator.formatThaiDate(friend.friendsSince);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Executive VIP Friend Profile Card ────────────────────
                Container(
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile1 : Colors.white,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 26, cornerSmoothing: 0.8),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      // Avatar with Glowing Squircle Ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF7A00), Color(0xFFFF5000)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.4 : 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceTile1 : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: (friend.user.avatarUrl != null && friend.user.avatarUrl!.isNotEmpty)
                                  ? Image.network(
                                      friend.user.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildAvatarInitial(friend.user.displayName),
                                    )
                                  : _buildAvatarInitial(friend.user.displayName),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Display Name
                      Text(
                        friend.user.displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // User Code Pill (Copyable)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: friend.user.userCode));
                          HapticFeedback.lightImpact();
                          AppToast.success(context, 'คัดลอกรหัสประจำตัว ${friend.user.userCode} แล้ว');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF2F4F8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : const Color(0xFFE4E8EF),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'รหัสประจำตัว: ${friend.user.userCode}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B900).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF00B900)),
                            SizedBox(width: 4),
                            Text(
                              'เพื่อน (Active)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00B900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF0F2F5)),
                      const SizedBox(height: 12),

                      // Friends Since Metadata Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'เป็นเพื่อนกันตั้งแต่',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            friendsSinceDateStr,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── 2. Outstanding Debt Status Card ─────────────────────────
                removalCheckAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: PingPayLoadingWidget(size: 80),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (check) {
                    if (!check.hasOutstandingDebt) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: ShapeDecoration(
                          color: isDark
                              ? const Color(0xFF0C2417)
                              : const Color(0xFFF0FDF4),
                          shape: SmoothRectangleBorder(
                            side: BorderSide(
                              color: const Color(0xFF22C55E).withValues(alpha: isDark ? 0.35 : 0.4),
                              width: 1.2,
                            ),
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.8),
                            ),
                          ),
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: isDark ? 0.05 : 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF16A34A),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ไม่มียอดหนี้ค้างชำระ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF16A34A),
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'คุณและเพื่อนท่านนี้เคลียร์ยอดเงินครบถ้วนแล้ว',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Outstanding Debt Exists
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: ShapeDecoration(
                        color: isDark ? const Color(0xFF261D0C) : const Color(0xFFFFFBEB),
                        shape: SmoothRectangleBorder(
                          side: BorderSide(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.4 : 0.5),
                            width: 1.2,
                          ),
                          borderRadius: const SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
                          ),
                        ),
                        shadows: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.05 : 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'มียอดค้างชำระระหว่างกัน',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (check.outstanding != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'คุณติดเพื่อน:',
                                        style: TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                                      ),
                                      Text(
                                        '฿${check.outstanding!.youOweFriend}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFFF3B30),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'เพื่อนติดคุณ:',
                                        style: TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                                      ),
                                      Text(
                                        '฿${check.outstanding!.friendOwesYou}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF16A34A),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Text(
                            '⚠️ ข้อมูลบิลและการเงินทั้งหมดถูกบันทึกอย่างโปร่งใสในระบบ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── 3. Remove Friend Action Button ──────────────────────────
                OutlinedButton.icon(
                  onPressed: actionState.isLoading
                      ? null
                      : () => _handleRemoveFriend(
                          context,
                          ref,
                          friend,
                          removalCheckAsync.value,
                        ),
                  icon: const Icon(Icons.person_remove_rounded, size: 18),
                  label: const Text(
                    'ลบเพื่อน (Remove Friend)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    side: BorderSide(
                      color: const Color(0xFFFF3B30).withValues(alpha: isDark ? 0.5 : 0.4),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarInitial(String displayName) {
    return Container(
      color: const Color(0xFFFFF0E6),
      alignment: Alignment.center,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 32,
          color: Color(0xFFFF5000),
        ),
      ),
    );
  }

  Future<void> _handleRemoveFriend(
    BuildContext context,
    WidgetRef ref,
    FriendItemModel friend,
    RemovalCheckModel? check,
  ) async {
    HapticFeedback.mediumImpact();
    final hasDebt = check?.hasOutstandingDebt ?? false;

    if (!hasDebt) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('ลบเพื่อน?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'คุณต้องการลบ "${friend.user.displayName}" ออกจากรายชื่อเพื่อนหรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'ลบเพื่อน',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final ok = await ref
            .read(friendActionsProvider.notifier)
            .removeFriend(friendshipId);
        if (context.mounted && ok) {
          AppToast.success(context, 'ลบเพื่อนเรียบร้อยแล้ว');
          context.pop();
        }
      }
      return;
    }

    // Has Outstanding Debt -> Strictly prohibit deletion as requested
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Color(0xFFFF3B30), size: 24),
            SizedBox(width: 8),
            Text(
              'ไม่สามารถลบเพื่อนได้',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คุณและ "${friend.user.displayName}" ยังมียอดเงินค้างชำระระหว่างกัน',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            if (check?.outstanding != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('คุณติดเพื่อน:', style: TextStyle(fontSize: 12.5)),
                        Text(
                          '฿${check!.outstanding!.youOweFriend}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF3B30)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('เพื่อนติดคุณ:', style: TextStyle(fontSize: 12.5)),
                        Text(
                          '฿${check.outstanding!.friendOwesYou}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'ระบบไม่อนุญาตให้ลบเพื่อนในขณะที่ยังมียอดเงินคงค้าง กรุณาชำระเงินหรือเคลียร์ยอดหนี้ให้ครบถ้วนก่อนดำเนินการ',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('เข้าใจแล้ว'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/payments');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ดูรายการหนี้สิน', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
