import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/pingpay_loading.dart';
import '../../payments/models/payment_models.dart';
import '../../payments/providers/payment_providers.dart';
import '../../payments/services/debt_age_calculator.dart';
import '../providers/friends_provider.dart';

enum LeaderboardCategory {
  longestOverdue, // 🐢 ค้างนานสุด
  fastestPayer, // ⚡ จ่ายไวสุด
  highestDebt, // 👑 ค้างเยอะสุด
}

class FriendLeaderboardScreen extends ConsumerStatefulWidget {
  const FriendLeaderboardScreen({super.key});

  @override
  ConsumerState<FriendLeaderboardScreen> createState() => _FriendLeaderboardScreenState();
}

class _FriendLeaderboardScreenState extends ConsumerState<FriendLeaderboardScreen> {
  LeaderboardCategory _selectedCategory = LeaderboardCategory.longestOverdue;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receivablesState = ref.watch(userReceivablesProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text(
          'ทำเนียบจัดอันดับเพื่อน 🏆',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => ref.read(userReceivablesProvider.notifier).loadReceivables(),
          ),
        ],
      ),
      body: receivablesState.isLoading
          ? const Center(child: PingPayLoadingWidget(size: 100))
          : _buildBody(context, receivablesState, isDark),
    );
  }

  Widget _buildBody(BuildContext context, UserReceivablesState state, bool isDark) {
    final allFriends = state.allFriends;

    // Filter and sort according to selected category
    List<ReceivableFriendModel> rankedList = [];

    switch (_selectedCategory) {
      case LeaderboardCategory.longestOverdue:
        // Filter friends with outstanding debt, sort by oldest debt start date (oldest first)
        rankedList = allFriends.where((f) => f.hasOutstandingDebt && f.totalOutstandingAmount > 0).toList()
          ..sort((a, b) => a.oldestDebtStartDate.compareTo(b.oldestDebtStartDate));
        break;

      case LeaderboardCategory.highestDebt:
        // Filter friends with debt, sort by total outstanding amount descending
        rankedList = allFriends.where((f) => f.hasOutstandingDebt && f.totalOutstandingAmount > 0).toList()
          ..sort((a, b) => b.totalOutstandingAmount.compareTo(a.totalOutstandingAmount));
        break;

      case LeaderboardCategory.fastestPayer:
        // Filter friends who have made payments, sort by total amount paid / settled bills
        rankedList = allFriends.where((f) => f.totalAmountPaid > 0).toList()
          ..sort((a, b) => b.totalAmountPaid.compareTo(a.totalAmountPaid));
        break;
    }

    return Column(
      children: [
        // ── 1. Category Switcher Tabs ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceTile2 : const Color(0xFFE9ECF0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildCategoryTab(
                  label: 'ค้างนานสุด 🐢',
                  category: LeaderboardCategory.longestOverdue,
                  isDark: isDark,
                ),
                _buildCategoryTab(
                  label: 'จ่ายไวสุด ⚡',
                  category: LeaderboardCategory.fastestPayer,
                  isDark: isDark,
                ),
                _buildCategoryTab(
                  label: 'ค้างเยอะสุด 👑',
                  category: LeaderboardCategory.highestDebt,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        // ── 2. Content: Podium + Leaderboard List ──────────────────────────
        Expanded(
          child: rankedList.isEmpty
              ? _buildEmptyState(isDark)
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Top 3 Podium View
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _buildPodiumSection(context, rankedList.take(3).toList(), isDark),
                      ),
                    ),

                    // Section Title for Rank 4+
                    if (rankedList.length > 3) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                          child: Text(
                            'อันดับอื่นๆ ในทำเนียบ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final itemIndex = index + 3;
                              if (itemIndex >= rankedList.length) return null;
                              final friend = rankedList[itemIndex];
                              return _buildRankRow(context, friend, itemIndex + 1, isDark);
                            },
                            childCount: rankedList.length - 3,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab({
    required String label,
    required LeaderboardCategory category,
    required bool isDark,
  }) {
    final isSelected = _selectedCategory == category;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedCategory = category;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceTile1 : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFFFF5000)
                  : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP 3 PODIUM VIEW
  // ==========================================
  Widget _buildPodiumSection(
    BuildContext context,
    List<ReceivableFriendModel> topThree,
    bool isDark,
  ) {
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 26, cornerSmoothing: 0.8),
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place (Left)
              if (second != null)
                Expanded(
                  child: _buildPodiumPillar(
                    context,
                    friend: second,
                    rank: 2,
                    podiumHeight: 110,
                    badgeColor: const Color(0xFF9E9E9E),
                    isDark: isDark,
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              // 1st Place (Center - Elevated)
              if (first != null)
                Expanded(
                  child: _buildPodiumPillar(
                    context,
                    friend: first,
                    rank: 1,
                    podiumHeight: 145,
                    badgeColor: const Color(0xFFFFD700),
                    isDark: isDark,
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              // 3rd Place (Right)
              if (third != null)
                Expanded(
                  child: _buildPodiumPillar(
                    context,
                    friend: third,
                    rank: 3,
                    podiumHeight: 90,
                    badgeColor: const Color(0xFFCD7F32),
                    isDark: isDark,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPillar(
    BuildContext context, {
    required ReceivableFriendModel friend,
    required int rank,
    required double podiumHeight,
    required Color badgeColor,
    required bool isDark,
  }) {
    final metricText = _getMetricText(friend);
    final isFirst = rank == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for #1
        if (isFirst)
          const Text('👑', style: TextStyle(fontSize: 22))
        else
          const SizedBox(height: 10),

        // Avatar
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: isFirst ? 64 : 52,
              height: isFirst ? 64 : 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [badgeColor, badgeColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.4),
                    blurRadius: isFirst ? 12 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
            Container(
              width: isFirst ? 58 : 46,
              height: isFirst ? 58 : 46,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile1 : Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: (friend.debtor.avatarUrl != null && friend.debtor.avatarUrl!.isNotEmpty)
                    ? Image.network(
                        friend.debtor.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildAvatarLetter(friend.debtor.displayName),
                      )
                    : _buildAvatarLetter(friend.debtor.displayName),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Friend Name
        Text(
          friend.debtor.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isFirst ? 14 : 12.5,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),

        // Metric text badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5000).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            metricText,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF5000),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),

        // 3D Podium Pillar
        Container(
          width: double.infinity,
          height: podiumHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      badgeColor.withValues(alpha: 0.25),
                      badgeColor.withValues(alpha: 0.08),
                    ]
                  : [
                      badgeColor.withValues(alpha: 0.3),
                      badgeColor.withValues(alpha: 0.12),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: isFirst ? 36 : 28,
                fontWeight: FontWeight.w900,
                color: badgeColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow(
    BuildContext context,
    ReceivableFriendModel friend,
    int rank,
    bool isDark,
  ) {
    final metricText = _getMetricText(friend);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFEBEFF5),
            width: 1,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Row(
        children: [
          // Rank Number Badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceTile2 : const Color(0xFFF0F2F5),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFFF5000).withValues(alpha: 0.15),
            child: Text(
              friend.debtor.displayName.isNotEmpty
                  ? friend.debtor.displayName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF5000),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name & ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.debtor.displayName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                Text(
                  'รหัส: ${friend.debtor.userCode}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                ),
              ],
            ),
          ),

          // Primary Metric Highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5000).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              metricText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF5000),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMetricText(ReceivableFriendModel friend) {
    switch (_selectedCategory) {
      case LeaderboardCategory.longestOverdue:
        final days = DebtAgeCalculator.calculateDaysOutstanding(friend.oldestDebtStartDate);
        return days == 0 ? 'ค้างวันนี้' : 'ค้าง $days วัน';
      case LeaderboardCategory.highestDebt:
        return '฿${friend.totalOutstandingAmount.toStringAsFixed(0)}';
      case LeaderboardCategory.fastestPayer:
        return 'จ่ายแล้ว ฿${friend.totalAmountPaid.toStringAsFixed(0)}';
    }
  }

  Widget _buildAvatarLetter(String displayName) {
    return Container(
      color: const Color(0xFFFFF0E6),
      alignment: Alignment.center,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 20,
          color: Color(0xFFFF5000),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                size: 40,
                color: Color(0xFFFF5000),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ยังไม่มีข้อมูลการจัดอันดับ',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'เมื่อมีการสร้างบิลและการชำระเงิน อันดับของเพื่อนจะปรากฏที่นี่',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
