import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pull_sensitivity_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentTabIndex = 0;
  bool _isPullTriggered = false;
  double _pullDistance = 0.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToCreateBill() {
    HapticFeedback.mediumImpact();
    context.push('/bills/create');
  }

  void _showSensitivitySettingsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final currentSensitivity = ref.watch(pullSensitivityProvider);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ตั้งค่าระยะการดึงจอ (Pull Gesture)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.bodyOnDark
                                : AppColors.ink,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted48,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'เลือกระยะความลึกในการดึงหน้าจอลงเพื่อเปิดหน้าสร้างบิล:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...PullSensitivity.values.map((sensitivity) {
                      final isSelected = currentSensitivity == sensitivity;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.2 : 0.08,
                                )
                              : (isDark
                                    ? AppColors.surfaceTile2
                                    : AppColors.canvasParchment),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white10
                                      : AppColors.dividerSoft),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            sensitivity.label,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                        ? AppColors.bodyOnDark
                                        : AppColors.ink),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                              : const Icon(
                                  Icons.radio_button_unchecked_rounded,
                                  color: AppColors.hairline,
                                ),
                          onTap: () {
                            ref
                                .read(pullSensitivityProvider.notifier)
                                .setSensitivity(sensitivity);
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final pullSensitivity = ref.watch(pullSensitivityProvider);
    final targetThreshold = pullSensitivity.threshold;
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceBlack
          : AppColors.canvasParchment,
      body: Stack(
        children: [
          // Background top pull hint area with progress indicator
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: isDark ? AppColors.surfaceTile1 : AppColors.surfacePearl,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(top: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: _pullDistance > 60 ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _pullDistance >= targetThreshold
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _pullDistance >= targetThreshold
                              ? Icons.check_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 26,
                          color: _pullDistance >= targetThreshold
                              ? Colors.white
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _pullDistance >= targetThreshold
                          ? 'ปล่อยเพื่อเปิดหน้าสร้างบิล'
                          : 'ดึงลงเพื่อสร้างบิล / จ่ายเงิน',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _pullDistance >= targetThreshold
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.bodyMuted
                                  : AppColors.inkMuted80),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Area
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is ScrollUpdateNotification) {
                final overscroll = notification.metrics.pixels;
                if (overscroll < 0) {
                  setState(() {
                    _pullDistance = -overscroll;
                  });
                  // Trigger only when pulled past user-configured threshold
                  if (overscroll <= -targetThreshold && !_isPullTriggered) {
                    _isPullTriggered = true;
                    _navigateToCreateBill();
                  }
                } else if (overscroll >= 0) {
                  if (_pullDistance != 0) {
                    setState(() {
                      _pullDistance = 0;
                    });
                  }
                  _isPullTriggered = false;
                }
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceBlack
                      : AppColors.canvasParchment,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Gradient Header Section
                    _buildTopHeader(context, user),

                    const SizedBox(height: 16),

                    // Daily Check-in / Rewards Promo Card
                    _buildDailyCheckInCard(context),

                    const SizedBox(height: 18),

                    // Section Title: Recommended Services
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'บริการแนะนำสำหรับคุณ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Recommended Banner Card
                    _buildRecommendedPromoCard(context),

                    const SizedBox(height: 100), // padding for bottom nav
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // 5-Tab Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTopHeader(BuildContext context, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.zero,
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
                  const Color(0xFFFF5000), // Vibrant TrueMoney/Shopee Orange
                  const Color(0xFFFF6A00),
                  const Color(0xFFFF8500),
                ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            children: [
              // Search Bar + Coins + Notification Row
              Row(
                children: [
                  // Search Input Squircle Pill
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(
                              cornerRadius: 21,
                              cornerSmoothing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ค้นหาเพื่อน หรือ รายการบิล',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Coin Capsule (Squircle)
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: ShapeDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 19, cornerSmoothing: 1.0),
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 18,
                          color: Color(0xFFFFD700),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '27',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Notification Bell with Badge (Squircle)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: ShapeDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 19,
                                cornerSmoothing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '4',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Sensitivity Settings Quick Trigger (Squircle)
                  GestureDetector(
                    onTap: _showSensitivitySettingsSheet,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(
                              cornerRadius: 19,
                              cornerSmoothing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 4 Core Action Buttons Row (Debt & Settlement Dashboard)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.folder_shared_rounded,
                    label: 'บิลของฉัน',
                    onTap: () {},
                  ),
                  _buildHeaderActionButton(
                    icon: Icons.arrow_downward_rounded,
                    label: 'เพื่อนติดเรา',
                    badge: '฿850',
                    onTap: () {},
                  ),
                  _buildHeaderActionButton(
                    icon: Icons.arrow_upward_rounded,
                    label: 'เราติดเพื่อน',
                    badge: '฿240',
                    onTap: () {},
                  ),
                  _buildHeaderActionButton(
                    icon: Icons.add_circle_rounded,
                    label: 'สร้างบิล',
                    onTap: _navigateToCreateBill,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // White/Dark Floating Debt Summary Card (Squircle)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: ShapeDecoration(
                  color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 22, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: ShapeDecoration(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(
                              cornerRadius: 12,
                              cornerSmoothing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user?.displayName ?? 'ยอดสุทธิที่รอเคลียร์',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.bodyMuted
                                      : AppColors.inkMuted48,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppColors.inkMuted48,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '610.00 บาท',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.bodyOnDark
                                      : AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '(รอรับเงิน)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _navigateToCreateBill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(
                              cornerRadius: 20,
                              cornerSmoothing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      child: const Text(
                        'หารบิลใหม่',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: ShapeDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 18, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Icon(icon, size: 26, color: Colors.white),
              ),
              if (badge != null)
                Positioned(
                  top: -5,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: const ShapeDecoration(
                      color: AppColors.error,
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 8, cornerSmoothing: 1.0),
                        ),
                      ),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCheckInCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        shape: SmoothRectangleBorder(
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.dividerSoft,
          ),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: ShapeDecoration(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 12, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เช็คอินรับเหรียญทุกวัน',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                    const Text(
                      'กลับมาเช็คอินอีกครั้งพรุ่งนี้นะ 😉',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted48,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 16, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: const Text(
                  'รับส่วนลด',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 7-Day Streak Rewards Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRewardDay('5 บาท', 'วันที่1', isChecked: true),
              _buildRewardDay('3 coins', 'วันที่2', isChecked: false),
              _buildRewardDay('12 บาท', 'วันที่3', isChecked: false),
              _buildRewardDay('15 บาท', 'วันที่4', isChecked: false),
              _buildRewardDay('5 coins', 'วันที่5', isChecked: false),
              _buildRewardDay('15 บาท', 'วันที่6', isChecked: false),
              _buildRewardDay('20 บาท', 'วันที่7', isChecked: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardDay(String reward, String day, {required bool isChecked}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: ShapeDecoration(
            color: isChecked
                ? AppColors.success
                : (isDark ? AppColors.surfaceTile2 : AppColors.canvasParchment),
            shape: SmoothRectangleBorder(
              side: BorderSide(
                color: isChecked
                    ? AppColors.success
                    : (isDark ? Colors.white10 : AppColors.hairline),
              ),
              borderRadius: const SmoothBorderRadius.all(
                SmoothRadius(cornerRadius: 12, cornerSmoothing: 1.0),
              ),
            ),
          ),
          alignment: Alignment.center,
          child: isChecked
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : const Icon(
                  Icons.monetization_on_outlined,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
        ),
        const SizedBox(height: 4),
        Text(
          reward,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.bodyOnDark : AppColors.ink,
          ),
        ),
        Text(
          day,
          style: const TextStyle(fontSize: 9, color: AppColors.inkMuted48),
        ),
      ],
    );
  }

  Widget _buildRecommendedPromoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/friends'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: ShapeDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                  ),
                ),
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'จัดการเพื่อนและกลุ่มหารบิล',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'เพิ่มเพื่อน ตอบรับคำขอ และตรวจสอบยอดหนี้ระหว่างกัน',
                    style: TextStyle(fontSize: 11, color: AppColors.inkMuted48),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.inkMuted48,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : AppColors.dividerSoft,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'หน้าหลัก'),
              _buildNavItem(
                1,
                Icons.account_balance_wallet_outlined,
                'การเงิน',
              ),
              _buildNavItem(2, Icons.receipt_long_outlined, 'รายการ'),
              _buildNavItem(3, Icons.card_giftcard_outlined, 'แลกคอยน์'),
              _buildNavItem(4, Icons.person_outline_rounded, 'ฉัน'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final color = isSelected
        ? (isDark ? AppColors.primaryOnDark : AppColors.primary)
        : AppColors.inkMuted48;

    return GestureDetector(
      onTap: () {
        if (index == 4) {
          _showSensitivitySettingsSheet();
        } else {
          setState(() {
            _currentTabIndex = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
