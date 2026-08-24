import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/pingpay_loading.dart';
import '../../payments/models/payment_models.dart';
import '../../payments/presentation/widgets/friend_receivable_detail_bottom_sheet.dart';
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
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFFAFBFD),
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
        backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFFAFBFD),
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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceTile2 : const Color(0xFFE9ECF0),
              borderRadius: BorderRadius.circular(14),
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
                    // Top Spotlight / Podium View
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                        child: rankedList.length == 1
                            ? _buildSingleChampionCard(context, rankedList[0], isDark)
                            : _buildPodiumSection(context, rankedList.take(3).toList(), isDark),
                      ),
                    ),

                    // Section Title for List
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'รายชื่อและอันดับ (${rankedList.length} คน)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                            ),
                            Text(
                              'แตะเพื่อดูรายละเอียด',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Leaderboard List Rows
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final friend = rankedList[index];
                            return _buildRankRow(context, friend, index + 1, isDark);
                          },
                          childCount: rankedList.length,
                        ),
                      ),
                    ),
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
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
  // SINGLE CHAMPION CARD (WHEN ONLY 1 PERSON)
  // ==========================================
  Widget _buildSingleChampionCard(
    BuildContext context,
    ReceivableFriendModel friend,
    bool isDark,
  ) {
    final metricText = _getMetricText(friend);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => FriendReceivableDetailBottomSheet.show(context, friend),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            shape: SmoothRectangleBorder(
              side: BorderSide(
                color: const Color(0xFFFFD700).withValues(alpha: isDark ? 0.4 : 0.6),
                width: 1.2,
              ),
              borderRadius: const SmoothBorderRadius.all(
                SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.8),
              ),
            ),
            shadows: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Crown + Halo Avatar
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceTile1 : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: (friend.debtor.avatarUrl != null && friend.debtor.avatarUrl!.isNotEmpty)
                          ? Image.network(
                              friend.debtor.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildAvatarLetter(friend.debtor.displayName, size: 24),
                            )
                          : _buildAvatarLetter(friend.debtor.displayName, size: 24),
                    ),
                  ),
                  const Positioned(
                    top: -14,
                    child: Text('👑', style: TextStyle(fontSize: 24)),
                  ),
                  Positioned(
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Text(
                        '#1 แชมป์',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF5B3A00),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Name & User Code
              Text(
                friend.debtor.displayName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'รหัส: ${friend.debtor.userCode}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                ),
              ),
              const SizedBox(height: 10),

              // Metric Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  metricText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF5000),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Additional Summary Info Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 14,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ยอดหนี้รวม ฿${friend.totalOutstandingAmount.toStringAsFixed(2)} • ${friend.bills.length} รายการ (แตะเพื่อดูบิล)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP 3 PODIUM VIEW (FOR 2+ PEOPLE)
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
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
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
                podiumHeight: 80,
                badgeColor: const Color(0xFFA0AEC0),
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
                podiumHeight: 105,
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
                podiumHeight: 65,
                badgeColor: const Color(0xFFCD7F32),
                isDark: isDark,
              ),
            )
          else
            const Expanded(child: SizedBox()),
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

    return GestureDetector(
      onTap: () => FriendReceivableDetailBottomSheet.show(context, friend),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown for #1
          if (isFirst)
            const Text('👑', style: TextStyle(fontSize: 18))
          else
            const SizedBox(height: 8),

          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isFirst ? 56 : 46,
                height: isFirst ? 56 : 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [badgeColor, badgeColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.35),
                      blurRadius: isFirst ? 10 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              Container(
                width: isFirst ? 50 : 40,
                height: isFirst ? 50 : 40,
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
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Friend Name
          Text(
            friend.debtor.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isFirst ? 13 : 11.5,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),

          // Metric text badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5000).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              metricText,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF5000),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),

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
                        badgeColor.withValues(alpha: 0.28),
                        badgeColor.withValues(alpha: 0.1),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: isFirst ? 30 : 22,
                  fontWeight: FontWeight.w900,
                  color: badgeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(
    BuildContext context,
    ReceivableFriendModel friend,
    int rank,
    bool isDark,
  ) {
    final metricText = _getMetricText(friend);

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFA0AEC0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = isDark ? Colors.white24 : const Color(0xFFE5E7EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => FriendReceivableDetailBottomSheet.show(context, friend),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Rank Number Badge
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? rankColor.withValues(alpha: 0.2)
                        : (isDark ? AppColors.surfaceTile2 : const Color(0xFFF0F2F5)),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: rank <= 3
                          ? (isDark ? Colors.white : const Color(0xFF1D1D1F))
                          : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                      ),
                    ),
                  ),
                  child: ClipSmoothRect(
                    radius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 11, cornerSmoothing: 0.6),
                    ),
                    child: (friend.debtor.avatarUrl != null && friend.debtor.avatarUrl!.isNotEmpty)
                        ? Image.network(
                            friend.debtor.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarLetter(friend.debtor.displayName, size: 14),
                          )
                        : _buildAvatarLetter(friend.debtor.displayName, size: 14),
                  ),
                ),
                const SizedBox(width: 10),

                // Name & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.debtor.displayName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    metricText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF5000),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? Colors.white30 : const Color(0xFFC7C7CC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMetricText(ReceivableFriendModel friend) {
    switch (_selectedCategory) {
      case LeaderboardCategory.longestOverdue:
        final days = DebtAgeCalculator.calculateDaysOutstanding(friend.oldestDebtStartDate);
        return days == 0 ? 'ค้างวันนี้' : 'ค้าง $days วัน';
      case LeaderboardCategory.highestDebt:
        return '฿${friend.totalOutstandingAmount.toStringAsFixed(2)}';
      case LeaderboardCategory.fastestPayer:
        return 'จ่ายแล้ว ฿${friend.totalAmountPaid.toStringAsFixed(2)}';
    }
  }

  Widget _buildAvatarLetter(String displayName, {double size = 18}) {
    return Container(
      color: const Color(0xFFFFF0E6),
      alignment: Alignment.center,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: size,
          color: const Color(0xFFFF5000),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Text('🎉', style: TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีข้อมูลการจัดอันดับ',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedCategory == LeaderboardCategory.longestOverdue ||
                      _selectedCategory == LeaderboardCategory.highestDebt
                  ? 'ไม่มีเพื่อนคนไหนติดหนี้คุณเลยในขณะนี้'
                  : 'ยังไม่มีประวัติการชำระเงินของเพื่อน',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
