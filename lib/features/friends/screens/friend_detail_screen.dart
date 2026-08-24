import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/widgets/pingpay_loading.dart';
import '../../payments/services/debt_age_calculator.dart';
import '../models/friend_models.dart';
import '../providers/friend_nickname_provider.dart';
import '../providers/friends_provider.dart';

class FriendDetailScreen extends ConsumerWidget {
  final String friendshipId;

  const FriendDetailScreen({super.key, required this.friendshipId});

  void _showSetNicknameDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String currentDisplayName,
    String? currentNickname,
  ) {
    final controller = TextEditingController(text: currentNickname ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded, color: Color(0xFFFF5000), size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'ตั้งชื่อเล่นให้เพื่อน',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ชื่อบัญชีจริง: $currentDisplayName',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkMuted48,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'เช่น พี่เอก, ต๋อง DevOps, น้องมายด์',
                labelText: 'ชื่อเล่น (บันทึกเฉพาะในเครื่องคุณ)',
                labelStyle: const TextStyle(fontSize: 12.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '* ชื่อเล่นนี้จะแสดงเฉพาะในเครื่องของคุณเท่านั้น',
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted48),
            ),
          ],
        ),
        actions: [
          if (currentNickname != null && currentNickname.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(friendNicknameProvider.notifier)
                    .removeNickname(userId);
                if (context.mounted) {
                  AppToast.success(context, 'ล้างชื่อเล่นเรียบร้อยแล้ว');
                }
              },
              child: const Text(
                'ล้างชื่อเล่น',
                style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNick = controller.text.trim();
              Navigator.pop(ctx);
              await ref
                  .read(friendNicknameProvider.notifier)
                  .setNickname(userId: userId, nickname: newNick);
              if (context.mounted) {
                AppToast.success(
                  context,
                  newNick.isEmpty
                      ? 'ล้างชื่อเล่นเรียบร้อยแล้ว'
                      : 'ตั้งชื่อเล่นเป็น "$newNick" แล้ว',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('บันทึก', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendAsync = ref.watch(friendDetailProvider(friendshipId));
    final removalCheckAsync = ref.watch(removalCheckProvider(friendshipId));
    final actionState = ref.watch(friendActionsProvider);
    final nicknamesMap = ref.watch(friendNicknameProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceBlack
          : const Color(0xFFFAFBFD),
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
        backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFFAFBFD),
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
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_off_rounded,
                    size: 36,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ไม่พบข้อมูลเพื่อนหรือถูกลบไปแล้ว',
                  style: TextStyle(
                    fontSize: 16,
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
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('กลับไปยังรายชื่อเพื่อน', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (friend) {
          final friendKey = (friend.user.id != null && friend.user.id!.isNotEmpty)
              ? friend.user.id!
              : friend.user.userCode;
          final friendsSinceDateStr = DebtAgeCalculator.formatThaiDate(friend.friendsSince);
          final nickname = nicknamesMap[friendKey];
          final hasNickname = nickname != null && nickname.trim().isNotEmpty;
          final effectiveName = hasNickname ? nickname : friend.user.displayName;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Profile Card ───────────────────────────────────────
                Container(
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile1 : Colors.white,
                    shape: SmoothRectangleBorder(
                      side: BorderSide(
                        color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                        width: 0.8,
                      ),
                      borderRadius: const SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.8),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.6),
                            ),
                          ),
                        ),
                        child: ClipSmoothRect(
                          radius: const SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.6),
                          ),
                          child: (friend.user.avatarUrl != null && friend.user.avatarUrl!.isNotEmpty)
                              ? Image.network(
                                  friend.user.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarInitial(effectiveName),
                                )
                              : _buildAvatarInitial(effectiveName),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Display Name & Nickname Edit Trigger
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              effectiveName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showSetNicknameDialog(
                              context,
                              ref,
                              friendKey,
                              friend.user.displayName,
                              nickname,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: Color(0xFFFF5000),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Real Name Subtitle if nickname is active
                      if (hasNickname) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ชื่อบัญชีจริง: ${friend.user.displayName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // User Code Pill (Copyable)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: friend.user.userCode));
                          HapticFeedback.lightImpact();
                          AppToast.success(context, 'คัดลอกรหัสประจำตัว ${friend.user.userCode} แล้ว');
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'รหัสประจำตัว: ${friend.user.userCode}',
                                style: TextStyle(
                                  fontSize: 11.5,
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
                      const SizedBox(height: 8),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF34C759)),
                            SizedBox(width: 3.5),
                            Text(
                              'เพื่อน (Active)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF34C759),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Divider(
                        height: 1,
                        thickness: 0.6,
                        color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                      ),
                      const SizedBox(height: 12),

                      // Friends Since Metadata Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'เป็นเพื่อนกันตั้งแต่',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            friendsSinceDateStr,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 2. Outstanding Debt Status Card ─────────────────────────
                removalCheckAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: PingPayLoadingWidget(size: 70),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (check) {
                    if (!check.hasOutstandingDebt) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: ShapeDecoration(
                          color: isDark ? AppColors.surfaceTile1 : Colors.white,
                          shape: SmoothRectangleBorder(
                            side: BorderSide(
                              color: const Color(0xFF34C759).withValues(alpha: isDark ? 0.35 : 0.4),
                              width: 0.8,
                            ),
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.8),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF34C759),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ไม่มียอดหนี้ค้างชำระ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF34C759),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    'คุณและเพื่อนท่านนี้เคลียร์ยอดเงินครบถ้วนแล้ว',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.inkMuted48,
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
                      padding: const EdgeInsets.all(16),
                      decoration: ShapeDecoration(
                        color: isDark ? AppColors.surfaceTile1 : Colors.white,
                        shape: SmoothRectangleBorder(
                          side: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                            width: 0.8,
                          ),
                          borderRadius: const SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.8),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFFFF5000),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'มียอดค้างชำระระหว่างกัน',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (check.outstanding != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                                  width: 0.8,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'คุณติดเพื่อน:',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '฿${check.outstanding!.youOweFriend}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFFF3B30),
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(
                                    height: 14,
                                    thickness: 0.6,
                                    color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'เพื่อนติดคุณ:',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '฿${check.outstanding!.friendOwesYou}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF34C759),
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '⚠️ ข้อมูลบิลและการเงินทั้งหมดถูกบันทึกอย่างโปร่งใสในระบบ',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

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
                  icon: const Icon(Icons.person_remove_rounded, size: 16),
                  label: const Text(
                    'ลบเพื่อน (Remove Friend)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    side: BorderSide(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
          fontSize: 28,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Color(0xFFFF3B30), size: 22),
            SizedBox(width: 8),
            Text(
              'ไม่สามารถลบเพื่อนได้',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คุณและ "${friend.user.displayName}" ยังมียอดเงินค้างชำระระหว่างกัน',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (check?.outstanding != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('คุณติดเพื่อน:', style: TextStyle(fontSize: 12)),
                        Text(
                          '฿${check!.outstanding!.youOweFriend}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF3B30)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('เพื่อนติดคุณ:', style: TextStyle(fontSize: 12)),
                        Text(
                          '฿${check.outstanding!.friendOwesYou}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34C759)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const Text(
              'ระบบไม่อนุญาตให้ลบเพื่อนในขณะที่ยังมียอดเงินคงค้าง กรุณาชำระเงินหรือเคลียร์ยอดหนี้ให้ครบถ้วนก่อนดำเนินการ',
              style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ดูรายการหนี้สิน', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
