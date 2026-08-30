import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bills/providers/bill_provider.dart';
import '../../friends/providers/friends_provider.dart';
import '../../payments/presentation/widgets/debt_acknowledgement_detail_sheet.dart';
import '../../payments/providers/payment_providers.dart';
import '../../notifications/presentation/notification_center_sheet.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../rewards/providers/reward_providers.dart';
import '../providers/pull_sensitivity_provider.dart';
import 'widgets/line_calendar_widget.dart';
import 'widgets/daily_timeline_section.dart';
import 'widgets/global_search_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _isPullTriggered = false;
  double _pullDistance = 0.0;
  late DateTime _selectedDate;
  late DateTime _lastInitDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _lastInitDay = _selectedDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userDebtsProvider.notifier).loadDebts(showLoading: false);
      ref.read(userReceivablesProvider.notifier).loadReceivables(showLoading: false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // If the day has changed since last init/resume, auto-select today
      if (today != _lastInitDay) {
        setState(() {
          _selectedDate = today;
          _lastInitDay = today;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _navigateToCreateBill() async {
    HapticFeedback.mediumImpact();
    final friendsAsync = ref.read(friendsListProvider);
    final friends = friendsAsync.valueOrNull ?? await ref.read(friendsRepositoryProvider).getFriends();
    if (friends.isEmpty && mounted) {
      _showNoFriendsBottomSheet();
      return;
    }
    if (mounted) {
      context.push('/bills/create');
    }
  }

  void _showNoFriendsBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: ShapeDecoration(
          color: isDark ? AppColors.surfaceBlack : Colors.white,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.7),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_off_rounded,
                color: Color(0xFFFF5000),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีเพื่อนในระบบ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'คุณต้องมีเพื่อนในระบบอย่างน้อย 1 คนก่อน จึงจะสามารถสร้างบิลหรือสแกนบิล OCR ได้',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/friends/scan');
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text(
                  'สแกน QR Code เพิ่มเพื่อน',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/friends/add');
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('ค้นหาด้วยรหัสเพื่อน (User ID)'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5000),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  void _showPendingDebtRequestsSheet(BuildContext context) {
    NotificationCenterSheet.show(context);
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
                  final newDist = -overscroll;
                  if ((newDist - _pullDistance).abs() > 4 ||
                      (newDist >= targetThreshold && _pullDistance < targetThreshold) ||
                      (newDist < targetThreshold && _pullDistance >= targetThreshold)) {
                    setState(() {
                      _pullDistance = newDist;
                    });
                  }
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

                    // Horizontal Line Calendar (Daily Timeline Selector)
                    Consumer(
                      builder: (context, ref, _) {
                        final billsAsync = ref.watch(myBillsProvider);
                        final currentUserId = ref.read(authStateProvider).user?.id;
                        final bills = (billsAsync.valueOrNull ?? [])
                            .where((b) => b.ownerId == currentUserId && !b.isCancelled && !b.isFullyWrittenOff)
                            .toList();
                        final userDebtsState = ref.watch(userDebtsProvider);
                        final debts = userDebtsState.allDebts;

                        // Collect dates that have active bills created by user (Orange dot)
                        final activeDates = bills
                            .where((b) => b.createdAt != null && !b.isCancelled && !b.isFullyWrittenOff)
                            .map((b) => DateFormat('yyyy-MM-dd').format(b.createdAt!))
                            .toSet();

                        // Collect dates where user has accepted/acknowledged debt to friends (Blue dot)
                        final debtDates = debts
                            .where((d) => d.isOutstanding && d.outstandingAmount > 0 && d.isAcknowledged && d.status != 'written_off' && d.status != 'cancelled')
                            .map((d) => DateFormat('yyyy-MM-dd').format(d.debtStartDate))
                            .toSet();

                        // Filter bills for currently selected date (exclude cancelled and fully written off)
                        final selectedDateStr =
                            DateFormat('yyyy-MM-dd').format(_selectedDate);
                        final filteredBills = bills.where((b) {
                          if (b.createdAt == null || b.isCancelled || b.isFullyWrittenOff) return false;
                          return DateFormat('yyyy-MM-dd').format(b.createdAt!) ==
                              selectedDateStr;
                        }).toList();

                        // Filter accepted debts for currently selected date (exclude written off and cancelled)
                        final filteredDebts = debts.where((d) {
                          if (!d.isOutstanding || d.outstandingAmount <= 0 || !d.isAcknowledged || d.status == 'written_off' || d.status == 'cancelled') return false;
                          return DateFormat('yyyy-MM-dd').format(d.debtStartDate) ==
                              selectedDateStr;
                        }).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LineCalendarWidget(
                              selectedDate: _selectedDate,
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedDate = date;
                                });
                              },
                              activeEventDates: activeDates,
                              debtEventDates: debtDates,
                            ),

                            const SizedBox(height: 14),

                            billsAsync.isLoading && bills.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: BillTimelineSkeleton(),
                                  )
                                : DailyTimelineSection(
                                    selectedDate: _selectedDate,
                                    bills: filteredBills,
                                    debts: filteredDebts,
                                    onCreateBill: _navigateToCreateBill,
                                  ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),

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

                    // Recommended Banner Cards
                    _buildMonthlyAnalyticsPromoCard(context),

                    const SizedBox(height: 10),

                    _buildRecommendedPromoCard(context),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
                  // Search Input Squircle Pill (Clickable)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        GlobalSearchSheet.show(context);
                      },
                      child: Container(
                        height: 42,
                        decoration: ShapeDecoration(
                          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.22),
                          shape: SmoothRectangleBorder(
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 21,
                                cornerSmoothing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ค้นหาเพื่อน หรือ รายการบิล',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Coin Capsule (Squircle)
                  // Rewards & Points Pill (Tap to open Rewards Store)
                  Consumer(
                    builder: (context, ref, _) {
                      final storeState = ref.watch(rewardStoreProvider);
                      final points = storeState.points;

                      return GestureDetector(
                        onTap: () => context.go('/rewards'),
                        child: Container(
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
                          child: Row(
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                size: 18,
                                color: Color(0xFFFFD700),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$points',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),

                  // Notification Bell with Badge (Squircle) for All Notifications & Debt Requests
                  Consumer(
                    builder: (context, ref, _) {
                      final unreadCount = ref.watch(totalUnreadNotificationCountProvider);

                      return GestureDetector(
                        onTap: () => NotificationCenterSheet.show(context),
                        child: Stack(
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
                            if (unreadCount > 0)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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
              Consumer(
                builder: (context, ref, _) {
                  final debtSummary = ref.watch(paymentSummaryProvider);
                  final receivableSummary = ref.watch(receivableSummaryProvider);

                  final receivableBadge = receivableSummary.totalOutstandingAmount > 0
                      ? '฿${receivableSummary.totalOutstandingAmount.toStringAsFixed(0)}'
                      : null;

                  final debtBadge = debtSummary.totalOutstandingAmount > 0
                      ? '฿${debtSummary.totalOutstandingAmount.toStringAsFixed(0)}'
                      : null;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderActionButton(
                        icon: Icons.folder_shared_rounded,
                        label: 'บิลของฉัน',
                        onTap: () => context.go('/bills/my'),
                      ),
                      _buildHeaderActionButton(
                        icon: Icons.arrow_downward_rounded,
                        label: 'เพื่อนติดเรา',
                        badge: receivableBadge,
                        onTap: () => context.go('/payments?tab=receivables'),
                      ),
                      _buildHeaderActionButton(
                        icon: Icons.arrow_upward_rounded,
                        label: 'เราติดเพื่อน',
                        badge: debtBadge,
                        onTap: () => context.go('/payments?tab=debts'),
                      ),
                      _buildHeaderActionButton(
                        icon: Icons.add_circle_rounded,
                        label: 'สร้างบิล',
                        onTap: _navigateToCreateBill,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // White/Dark Floating Receivable Summary Card (เงินที่เราต้องได้คืน / เพื่อนติดเรา)
              Consumer(
                builder: (context, ref, _) {
                  final summary = ref.watch(receivableSummaryProvider);

                  return GestureDetector(
                    onTap: () => context.go('/payments?tab=receivables'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: ShapeDecoration(
                        color: isDark
                            ? AppColors.surfaceTile1
                            : AppColors.canvas,
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(
                              cornerRadius: 22,
                              cornerSmoothing: 1.0,
                            ),
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
                              Icons.call_received_rounded,
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
                                      'รอรับเงินคืน (${summary.debtorCount} คน)',
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
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: AppColors.inkMuted48,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '฿${summary.totalOutstandingAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.bodyOnDark
                                        : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => context.go('/payments?tab=receivables'),
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
                              'ดูรายการ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                    'จัดการเพื่อนและรายชื่อ',
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

  Widget _buildMonthlyAnalyticsPromoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/analytics/monthly'),
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
                color: const Color(0xFFFF5000).withValues(alpha: isDark ? 0.2 : 0.1),
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 14, cornerSmoothing: 1.0),
                  ),
                ),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Color(0xFFFF5000),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สรุปค่าใช้จ่ายและกราฟรายเดือน',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'วิเคราะห์แนวโน้มรายรับ-รายจ่าย และสถิติบิลประจำเดือน',
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
}
