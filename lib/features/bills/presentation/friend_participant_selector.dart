import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/pingpay_loading.dart';
import '../../friends/providers/friends_provider.dart';
import '../providers/bill_provider.dart';

class FriendParticipantSelector extends ConsumerWidget {
  const FriendParticipantSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    final billState = ref.watch(billCreationProvider);
    final billNotifier = ref.read(billCreationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return friendsAsync.when(
      loading: () => const PingPayLoadingWidget(size: 120),
      error: (err, _) =>
          Center(child: Text('โหลดรายชื่อเพื่อนไม่สำเร็จ: $err')),
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(child: Text('ไม่มีรายชื่อเพื่อน'));
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: friends.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) {
            final friend = friends[idx];
            final friendUserId = friend.user.id ?? friend.friendshipId;
            final isSelected = billState.participants.any(
              (p) => p.userId == friendUserId,
            );

            return Material(
              color: isDark
                  ? AppColors.surfaceTile1
                  : (isSelected ? const Color(0xFFFFF7F2) : Colors.white),
              shape: SmoothRectangleBorder(
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFFF6A00)
                      : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                  width: isSelected ? 1.5 : 1.0,
                ),
                borderRadius: const SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
                ),
              ),
              child: InkWell(
                onTap: () => billNotifier.toggleFriendSelection(friend),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFFFF0E6),
                        child: Text(
                          friend.user.displayName.isNotEmpty
                              ? friend.user.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF5000),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friend.user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'รหัส: ${friend.user.userCode}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: isSelected,
                        activeColor: const Color(0xFFFF5000),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        onChanged: (_) =>
                            billNotifier.toggleFriendSelection(friend),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
