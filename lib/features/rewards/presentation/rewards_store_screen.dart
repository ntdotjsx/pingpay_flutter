import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/animations/animated_counter_text.dart';
import '../../../core/animations/animated_list_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/input_validators.dart';
import '../../../core/widgets/pingpay_loading.dart';
import '../models/reward_models.dart';
import '../providers/reward_providers.dart';

class RewardsStoreScreen extends ConsumerStatefulWidget {
  const RewardsStoreScreen({super.key});

  @override
  ConsumerState<RewardsStoreScreen> createState() => _RewardsStoreScreenState();
}

class _RewardsStoreScreenState extends ConsumerState<RewardsStoreScreen> {
  int _selectedTab = 0; // 0: ของรางวัลทั้งหมด, 1: ประวัติการแลก

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeState = ref.watch(rewardStoreProvider);
    final catalogAsync = ref.watch(rewardCatalogProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          ref.invalidate(rewardStoreProvider);
          ref.invalidate(rewardCatalogProvider);
          ref.invalidate(redemptionHistoryProvider);
        },
        color: const Color(0xFFFF5000),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Container(
            color: isDark ? AppColors.surfaceBlack : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Signature Executive Header & Points Hero ───────────
                _buildExecutiveHeader(context, isDark, storeState),

                const SizedBox(height: 14),

                // ── 2. Segmented Capsule Switcher ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceTile1 : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentTab(
                          label: 'ของรางวัลทั้งหมด',
                          icon: Icons.card_giftcard_rounded,
                          isSelected: _selectedTab == 0,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTab = 0);
                          },
                        ),
                        _buildSegmentTab(
                          label: 'ประวัติการแลก',
                          icon: Icons.history_rounded,
                          isSelected: _selectedTab == 1,
                          isDark: isDark,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTab = 1);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── 3. Tab Content ────────────────────────────────────────
                _selectedTab == 0
                    ? _buildCatalogSection(context, isDark, storeState, catalogAsync)
                    : _buildRedemptionHistorySection(isDark),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TOP SIGNATURE HEADER
  // =========================================================================
  Widget _buildExecutiveHeader(
    BuildContext context,
    bool isDark,
    RewardStoreState storeState,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.surfaceTile1,
                  AppColors.surfaceTile2,
                  AppColors.surfaceTile3,
                ]
              : [
                  const Color(0xFFFF5000),
                  const Color(0xFFFF6A00),
                  const Color(0xFFFF8500),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Title + Level Badge Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'แลกของรางวัล',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'ใช้แต้มสะสมแลกรับของรางวัลส่งตรงถึงบ้าน',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),

                  // Level Tier Capsule Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showLevelDetailsDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            storeState.tier.badge,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Lv.${storeState.tier.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Points Balance Hero Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'แต้มสะสมของคุณ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            size: 24,
                            color: Color(0xFFFFD700),
                          ),
                          const SizedBox(width: 6),
                          AnimatedCounterText(
                            value: storeState.points.toDouble(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'แต้ม',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Tier Title Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: ShapeDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 10, cornerSmoothing: 1.0),
                        ),
                      ),
                    ),
                    child: Text(
                      storeState.tier.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 3. Level Progression & Benefits Bar in Frosted Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ระดับ: ${storeState.tier.title}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        Text(
                          'รับแต้มสูงสุด +${storeState.tier.rewardPointsEarned} แต้ม/บิล',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: storeState.tier.nextTierProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceTile2 : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? const Color(0xFFFF5000)
                    : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.2,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.ink)
                      : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // REWARDS CATALOG GRID SECTION
  // =========================================================================
  Widget _buildCatalogSection(
    BuildContext context,
    bool isDark,
    RewardStoreState storeState,
    AsyncValue<List<RewardItemModel>> catalogAsync,
  ) {
    return catalogAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: PingPayLoadingWidget(
          message: 'กำลังโหลดรายการของรางวัล...',
          size: 110,
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text('เกิดข้อผิดพลาด: $err'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: Text('ไม่มีของรางวัลในขณะนี้')),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final canAfford = storeState.points >= item.pointsCost;

              return AnimatedListItem(
                index: index,
                child: _buildRewardItemCard(
                  context: context,
                  item: item,
                  storePoints: storeState.points,
                  canAfford: canAfford,
                  isDark: isDark,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRewardItemCard({
    required BuildContext context,
    required RewardItemModel item,
    required int storePoints,
    required bool canAfford,
    required bool isDark,
  }) {
    final deficit = item.pointsCost - storePoints;

    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
            width: 0.8,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.9),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Product Image / Cover
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackImage(),
                    )
                  : _buildFallbackImage(),
            ),
          ),

          // 2. Details & Action Button
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),

                // Points Tag
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 15,
                      color: Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.pointsCost} แต้ม',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF5000),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: item.inStock > 0
                        ? () {
                            if (canAfford) {
                              HapticFeedback.mediumImpact();
                              _showRedeemBottomSheet(context, item);
                            } else {
                              HapticFeedback.lightImpact();
                              AppToast.info(context, 'คุณยังขาดอีก $deficit แต้มในการแลกรับของรางวัลนี้');
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.inStock <= 0
                          ? (isDark ? Colors.white12 : const Color(0xFFE5E7EB))
                          : (canAfford
                              ? const Color(0xFFFF5000)
                              : (isDark ? AppColors.surfaceTile2 : const Color(0xFFF3F4F6))),
                      foregroundColor: item.inStock <= 0
                          ? AppColors.inkMuted48
                          : (canAfford
                              ? Colors.white
                              : (isDark ? AppColors.bodyMuted : AppColors.inkMuted80)),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      item.inStock <= 0
                          ? 'สินค้าหมด'
                          : (canAfford ? 'แลกรางวัล' : 'ขาดอีก $deficit แต้ม'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: canAfford ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFFFF5000).withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.card_giftcard_rounded,
          size: 36,
          color: Color(0xFFFF5000),
        ),
      ),
    );
  }

  // =========================================================================
  // REDEMPTION HISTORY SECTION
  // =========================================================================
  Widget _buildRedemptionHistorySection(bool isDark) {
    final historyAsync = ref.watch(redemptionHistoryProvider);

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: PingPayLoadingWidget(
          message: 'กำลังโหลดประวัติการแลก...',
          size: 110,
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text('เกิดข้อผิดพลาด: $err')),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 38,
                    color: Color(0xFFFF5000),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ยังไม่มีประวัติการแลกของรางวัล',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'เมื่อคุณแลกของรางวัล รายการและสถานะจัดส่งจะปรากฏที่นี่',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final redemption = items[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surfaceTile1 : Colors.white,
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                shape: SmoothRectangleBorder(
                  side: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
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
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Color(0xFF34C759),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              redemption.rewardItem.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'แลกเมื่อ ${_formatDate(redemption.createdAt)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(redemption.status, isDark),
                    ],
                  ),
                  if (redemption.trackingNumber != null && redemption.trackingNumber!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF0F2F5)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'เลขพัสดุ: ${redemption.trackingNumber}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.bodyMuted : AppColors.ink,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: redemption.trackingNumber!));
                            AppToast.success(context, 'คัดลอกเลขพัสดุแล้ว');
                          },
                          child: const Text(
                            'คัดลอก',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF5000),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'delivered':
        bg = const Color(0xFF34C759).withValues(alpha: 0.12);
        fg = const Color(0xFF34C759);
        label = 'จัดส่งสำเร็จ';
        break;
      case 'shipped':
        bg = const Color(0xFF007AFF).withValues(alpha: 0.12);
        fg = const Color(0xFF007AFF);
        label = 'กำลังจัดส่ง';
        break;
      case 'cancelled':
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
        label = 'ยกเลิกแล้ว';
        break;
      default:
        bg = const Color(0xFFFF9500).withValues(alpha: 0.12);
        fg = const Color(0xFFFF9500);
        label = 'กำลังเตรียมของ';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  // =========================================================================
  // DIALOGS & BOTTOM SHEETS
  // =========================================================================
  void _showLevelDetailsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tiers = [
      UserTierLevel.calculateFromPoints(0),
      UserTierLevel.calculateFromPoints(50),
      UserTierLevel.calculateFromPoints(200),
      UserTierLevel.calculateFromPoints(500),
      UserTierLevel.calculateFromPoints(1000),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ระดับสมาชิก PingPay Tiers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ยิ่งชำระบิลตรงเวลา ยิ่งได้แต้มสะสมต่อบิลสูงขึ้น',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
            const SizedBox(height: 14),
            ...tiers.map((t) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(t.badge, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t.title} (Lv.${t.level})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                            ),
                          ),
                          Text(
                            'สะสม ${t.minAmount} แต้มขึ้นไป',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${t.rewardPointsEarned} แต้ม/บิล',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF5000),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showRedeemBottomSheet(BuildContext context, RewardItemModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                top: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.8),
              ),
            ),
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFFF5000).withValues(alpha: 0.1),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Color(0xFFFF5000),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                              ),
                            ),
                            Text(
                              'ใช้ ${item.pointsCost} แต้มในการแลก',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFF5000),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้รับ',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                      isDense: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อผู้รับ' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'เบอร์โทรศัพท์ติดต่อ',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                      isDense: true,
                    ),
                    validator: InputValidators.validatePhoneNumber,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ที่อยู่จัดส่งและรหัสไปรษณีย์',
                      prefixIcon: Icon(Icons.home_outlined, size: 18),
                      isDense: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกที่อยู่จัดส่ง' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);

                      final success = await ref
                          .read(rewardStoreProvider.notifier)
                          .redeemReward(
                            rewardItemId: item.id,
                            recipientName: nameCtrl.text.trim(),
                            phoneNumber: phoneCtrl.text.trim(),
                            shippingAddress: addressCtrl.text.trim(),
                          );

                      if (context.mounted) {
                        if (success) {
                          AppToast.success(context, 'แลกของรางวัลสำเร็จ! กำลังเตรียมการจัดส่ง');
                          ref.invalidate(redemptionHistoryProvider);
                        } else {
                          AppToast.error(context, 'เกิดข้อผิดพลาดในการแลกของรางวัล');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5000),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ยืนยันการแลกของรางวัล',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
