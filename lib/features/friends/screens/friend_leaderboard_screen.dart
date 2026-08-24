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
import '../providers/friend_nickname_provider.dart';
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
    final nicknamesMap = ref.watch(friendNicknameProvider);

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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceTile2 : const Color(0xFFE9ECF0),
              borderRadius: BorderRadius.circular(12),
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

        // ── 2. Content: Game Podium + Ranked List Below ───────────────────
        Expanded(
          child: rankedList.isEmpty
              ? _buildEmptyState(isDark)
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Top 3 Game Podium (แท่นรับรางวัลเหมือนในเกม)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: _buildGamePodiumCard(context, rankedList, nicknamesMap, isDark),
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
                              'รายชื่อและอันดับทั้งหมด (${rankedList.length} คน)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                            ),
                            Text(
                              'แตะเพื่อดูรายละเอียดบิล',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Full Rankings List Below (รายชื่อลงมาด้านล่าง)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final friend = rankedList[index];
                            final nickname = nicknamesMap[friend.debtor.id] ??
                                nicknamesMap[friend.debtor.userCode];
                            return _buildRankRow(context, friend, index + 1, nickname, isDark);
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
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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

  // =========================================================================
  // GAME-STYLE 3D PODIUM SECTION (3 อันดับแรกอยู่บนแท่น เหมือนในเกม)
  // =========================================================================
  Widget _buildGamePodiumCard(
    BuildContext context,
    List<ReceivableFriendModel> rankedList,
    Map<String, String> nicknamesMap,
    bool isDark,
  ) {
    final first = rankedList.isNotEmpty ? rankedList[0] : null;
    final second = rankedList.length > 1 ? rankedList[1] : null;
    final third = rankedList.length > 2 ? rankedList[2] : null;

    final firstNick = first != null
        ? (nicknamesMap[first.debtor.id] ?? nicknamesMap[first.debtor.userCode])
        : null;
    final secondNick = second != null
        ? (nicknamesMap[second.debtor.id] ?? nicknamesMap[second.debtor.userCode])
        : null;
    final thirdNick = third != null
        ? (nicknamesMap[third.debtor.id] ?? nicknamesMap[third.debtor.userCode])
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
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
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Podium Header Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('👑', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Text(
                  'TOP 3 บนแท่นเกียรติยศ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8B6508),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3-Place Podium Pillars Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place (Left - Silver)
              Expanded(
                child: _buildPodiumStep(
                  context,
                  friend: second,
                  nickname: secondNick,
                  rank: 2,
                  podiumHeight: 80,
                  badgeColor: const Color(0xFFA0AEC0),
                  medalEmoji: '🥈',
                  isDark: isDark,
                ),
              ),

              // 1st Place (Center - Gold - Highest)
              Expanded(
                child: _buildPodiumStep(
                  context,
                  friend: first,
                  nickname: firstNick,
                  rank: 1,
                  podiumHeight: 110,
                  badgeColor: const Color(0xFFFFD700),
                  medalEmoji: '👑',
                  isDark: isDark,
                ),
              ),

              // 3rd Place (Right - Bronze)
              Expanded(
                child: _buildPodiumStep(
                  context,
                  friend: third,
                  nickname: thirdNick,
                  rank: 3,
                  podiumHeight: 62,
                  badgeColor: const Color(0xFFCD7F32),
                  medalEmoji: '🥉',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumStep(
    BuildContext context, {
    required ReceivableFriendModel? friend,
    required String? nickname,
    required int rank,
    required double podiumHeight,
    required Color badgeColor,
    required String medalEmoji,
    required bool isDark,
  }) {
    final isFirst = rank == 1;
    final hasFriend = friend != null;
    final displayName = hasFriend
        ? (nickname != null && nickname.isNotEmpty ? nickname : friend.debtor.displayName)
        : '-';
    final metricText = hasFriend ? _getMetricText(friend) : 'ว่าง';

    return GestureDetector(
      onTap: hasFriend
          ? () => FriendReceivableDetailBottomSheet.show(context, friend)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Medal / Crown Icon
          Text(
            medalEmoji,
            style: TextStyle(fontSize: isFirst ? 20 : 16),
          ),
          const SizedBox(height: 2),

          // Avatar / Placeholder
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isFirst ? 58 : 46,
                height: isFirst ? 58 : 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasFriend
                      ? LinearGradient(
                          colors: [badgeColor, badgeColor.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: hasFriend
                      ? null
                      : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                  boxShadow: hasFriend
                      ? [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.35),
                            blurRadius: isFirst ? 10 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
              Container(
                width: isFirst ? 52 : 40,
                height: isFirst ? 52 : 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceTile1 : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: hasFriend
                      ? (friend.debtor.avatarUrl != null && friend.debtor.avatarUrl!.isNotEmpty
                          ? Image.network(
                              friend.debtor.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildAvatarLetter(displayName),
                            )
                          : _buildAvatarLetter(displayName))
                      : Center(
                          child: Text(
                            '?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white30 : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
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
                      fontSize: 8.5,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isFirst ? 13 : 11.5,
                fontWeight: FontWeight.w800,
                color: hasFriend
                    ? (isDark ? AppColors.bodyOnDark : AppColors.ink)
                    : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),

          // Metric Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: hasFriend
                  ? const Color(0xFFFF5000).withValues(alpha: 0.1)
                  : (isDark ? Colors.white10 : const Color(0xFFF0F2F5)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              metricText,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: hasFriend
                    ? const Color(0xFFFF5000)
                    : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),

          // 3D Game Podium Pillar Step (แท่นรับรางวัล)
          Container(
            width: double.infinity,
            height: podiumHeight,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        badgeColor.withValues(alpha: hasFriend ? 0.35 : 0.12),
                        badgeColor.withValues(alpha: hasFriend ? 0.12 : 0.04),
                      ]
                    : [
                        badgeColor.withValues(alpha: hasFriend ? 0.38 : 0.15),
                        badgeColor.withValues(alpha: hasFriend ? 0.14 : 0.05),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(
                color: badgeColor.withValues(alpha: hasFriend ? 0.45 : 0.2),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: isFirst ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  color: hasFriend ? badgeColor : badgeColor.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FULL RANKINGS LIST ROW (รายชื่อลงมาด้านล่าง)
  // =========================================================================
  Widget _buildRankRow(
    BuildContext context,
    ReceivableFriendModel friend,
    int rank,
    String? nickname,
    bool isDark,
  ) {
    final metricText = _getMetricText(friend);
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final effectiveName = hasNickname ? nickname : friend.debtor.displayName;

    Color rankColor;
    String rankEmoji = '';
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankEmoji = '🥇';
    } else if (rank == 2) {
      rankColor = const Color(0xFFA0AEC0);
      rankEmoji = '🥈';
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankEmoji = '🥉';
    } else {
      rankColor = isDark ? Colors.white24 : const Color(0xFFE5E7EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: rank <= 3
                ? rankColor.withValues(alpha: isDark ? 0.35 : 0.5)
                : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
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
                // Rank Number Badge with Medal
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? rankColor.withValues(alpha: 0.18)
                        : (isDark ? AppColors.surfaceTile2 : const Color(0xFFF0F2F5)),
                    shape: BoxShape.circle,
                  ),
                  child: rank <= 3
                      ? Text(
                          rankEmoji,
                          style: const TextStyle(fontSize: 16),
                        )
                      : Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
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
                            errorBuilder: (_, __, ___) => _buildAvatarLetter(effectiveName, size: 14),
                          )
                        : _buildAvatarLetter(effectiveName, size: 14),
                  ),
                ),
                const SizedBox(width: 10),

                // Name, Nickname & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              effectiveName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasNickname) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${friend.debtor.displayName})',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'รหัส: ${friend.debtor.userCode}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                        ),
                      ),
                    ],
                  ),
                ),

                // Primary Metric Highlight Pill
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
