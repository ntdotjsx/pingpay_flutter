import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
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
          : const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text(
          'ข้อมูลเพื่อน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: friendAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_off_rounded,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 14),
              const Text(
                'ไม่พบข้อมูลเพื่อนหรือถูกลบไปแล้ว',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('กลับไปยังรายชื่อเพื่อน'),
              ),
            ],
          ),
        ),
        data: (friend) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile1 : Colors.white,
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFFFF0E6),
                        child: Text(
                          friend.user.displayName.isNotEmpty
                              ? friend.user.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: Color(0xFFFF5000),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        friend.user.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'รหัสประจำตัว: ${friend.user.userCode}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'เพื่อน (Active)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'เป็นเพื่อนกันตั้งแต่',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          Text(
                            '${friend.friendsSince.day}/${friend.friendsSince.month}/${friend.friendsSince.year}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Outstanding Debt Status Card
                removalCheckAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (check) {
                    if (!check.hasOutstandingDebt) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF0FDF4),
                          shape: const SmoothRectangleBorder(
                            side: BorderSide(color: Color(0xFFBBF7D0)),
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 18,
                                cornerSmoothing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF00B14F),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ไม่มียอดหนี้ค้างชำระ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF15803D),
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'คุณและเพื่อนท่านนี้เคลียร์ยอดเงินครบถ้วนแล้ว',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF166534),
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
                        color: const Color(0xFFFFFBEB),
                        shape: const SmoothRectangleBorder(
                          side: BorderSide(color: Color(0xFFFDE68A)),
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(
                              cornerRadius: 20,
                              cornerSmoothing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFD97706),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'มียอดค้างชำระระหว่างกัน',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (check.outstanding != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'คุณติดเพื่อน:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF78350F),
                                  ),
                                ),
                                Text(
                                  '฿${check.outstanding!.youOweFriend}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'เพื่อนติดคุณ:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF78350F),
                                  ),
                                ),
                                Text(
                                  '฿${check.outstanding!.friendOwesYou}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00B14F),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Text(
                            '⚠️ หมายเหตุ: การลบเพื่อนจะไม่ลบประวัติบิลและยอดหนี้ที่มีอยู่ ข้อมูลทางการเงินจะยังคงอยู่ครบถ้วน',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Remove Friend Button
                OutlinedButton(
                  onPressed: actionState.isLoading
                      ? null
                      : () => _handleRemoveFriend(
                          context,
                          ref,
                          friend,
                          removalCheckAsync.value,
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_remove_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'ลบเพื่อน (Remove Friend)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRemoveFriend(
    BuildContext context,
    WidgetRef ref,
    FriendItemModel friend,
    RemovalCheckModel? check,
  ) async {
    final hasDebt = check?.hasOutstandingDebt ?? false;

    if (!hasDebt) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ลบเพื่อน?'),
          content: Text(
            'คุณต้องการลบ "${friend.user.displayName}" ออกจากรายชื่อเพื่อนหรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'ลบเพื่อน',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบเพื่อนเรียบร้อยแล้ว'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
      return;
    }

    // Has Outstanding Debt -> Show strong warning dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('คำเตือน: มียอดหนี้คงค้าง'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คุณยังมียอดเงินที่ยังไม่ได้เคลียร์กับ "${friend.user.displayName}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (check?.outstanding != null) ...[
              Text('• คุณติดเพื่อน: ฿${check!.outstanding!.youOweFriend}'),
              Text('• เพื่อนติดคุณ: ฿${check.outstanding!.friendOwesYou}'),
              const SizedBox(height: 10),
            ],
            const Text(
              'การลบเพื่อนจะยุติความสัมพันธ์ในแอปเท่านั้น โดย "จะไม่ลบหรือเปลี่ยนแปลงประวัติการเป็นหนี้และสลิปหลักฐานใดๆ ทั้งสิ้น"',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'ยืนยันลบเพื่อนต่อไป',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ref
          .read(friendActionsProvider.notifier)
          .removeFriend(friendshipId, confirmOutstandingDebt: true);
      if (context.mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบเพื่อนเรียบร้อยแล้ว (ข้อมูลหนี้ยังคงอยู่ครบถ้วน)'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    }
  }
}
