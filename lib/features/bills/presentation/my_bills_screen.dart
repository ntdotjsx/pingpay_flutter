import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/animations/animated_counter_text.dart';
import '../../../core/animations/animated_list_item.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../auth/providers/auth_provider.dart';
import '../../friends/providers/friends_provider.dart';
import '../../home/presentation/widgets/global_search_sheet.dart';
import '../../payments/services/debt_age_calculator.dart';
import '../../rewards/providers/reward_providers.dart';
import '../models/bill_models.dart';
import '../providers/bill_provider.dart';

enum MyBillsFilter {
  all,
  unpaid,
  partiallyPaid,
  paid,
}

final myBillsFilterProvider = StateProvider<MyBillsFilter>((ref) => MyBillsFilter.all);

class MyBillsScreen extends ConsumerWidget {
  const MyBillsScreen({super.key});

  Future<void> _handleCreateBill(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final friendsAsync = ref.read(friendsListProvider);
    final friends = friendsAsync.valueOrNull ?? await ref.read(friendsRepositoryProvider).getFriends();
    if (friends.isEmpty && context.mounted) {
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
            ],
          ),
        ),
      );
      return;
    }
    if (context.mounted) {
      context.push('/bills/create');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(myBillsProvider);
    final selectedFilter = ref.watch(myBillsFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleCreateBill(context, ref),
        backgroundColor: const Color(0xFFFF5000),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'สร้างบิลใหม่',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          return ref.refresh(myBillsProvider.future);
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
                // ── 1. Top Executive Gradient Header ────────────────────────
                billsAsync.when(
                  loading: () => _buildHeader(
                    context,
                    ref: ref,
                    isDark: isDark,
                    totalBillAmount: 0,
                    totalBillsCount: 0,
                    unpaidBillsCount: 0,
                    totalDebtors: 0,
                  ),
                  error: (_, __) => _buildHeader(
                    context,
                    ref: ref,
                    isDark: isDark,
                    totalBillAmount: 0,
                    totalBillsCount: 0,
                    unpaidBillsCount: 0,
                    totalDebtors: 0,
                  ),
                  data: (allBills) {
                    final currentUserId = ref.read(authStateProvider).user?.id;
                    final bills = allBills.where((b) => b.ownerId == currentUserId).toList();
                    final totalBillAmount = bills.fold(0.0, (acc, b) => acc + b.totalAmount);
                    final uniqueDebtorIds = <String>{};
                    for (final b in bills) {
                      for (final item in b.items) {
                        if (item.debtorId.isNotEmpty) {
                          uniqueDebtorIds.add(item.debtorId);
                        }
                      }
                    }
                    final totalDebtors = uniqueDebtorIds.length;
                    final unpaidBillsCount = bills.where((b) =>
                      !b.isCancelled &&
                      !b.isFullyWrittenOff &&
                      !b.isFullyPaid &&
                      b.totalOutstandingAmount > 0
                    ).length;

                    return _buildHeader(
                      context,
                      ref: ref,
                      isDark: isDark,
                      totalBillAmount: totalBillAmount,
                      totalBillsCount: bills.length,
                      unpaidBillsCount: unpaidBillsCount,
                      totalDebtors: totalDebtors,
                    );
                  },
                ),

                // ── 2. Content & Bills List ───────────────────────────────────
                billsAsync.when(
                  loading: () => _buildSkeletonLoading(isDark),
                  error: (err, _) => _buildErrorState(context, ref, err.toString(), isDark),
                  data: (allBills) {
                    final currentUserId = ref.read(authStateProvider).user?.id;
                    final bills = allBills.where((b) => b.ownerId == currentUserId).toList();

                    // Filter bills
                    final filteredBills = bills.where((b) {
                      switch (selectedFilter) {
                        case MyBillsFilter.unpaid:
                          return b.status == 'unpaid' && !b.isCancelled && !b.isFullyWrittenOff;
                        case MyBillsFilter.partiallyPaid:
                          return b.status == 'partially_paid' || b.status == 'partially_written_off';
                        case MyBillsFilter.paid:
                          return b.status == 'paid' || b.status == 'fully_paid' || b.status == 'fully_written_off';
                        case MyBillsFilter.all:
                          return true;
                      }
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 14),

                        // Filter Chips Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  ref: ref,
                                  label: 'ทั้งหมด (${bills.length})',
                                  filter: MyBillsFilter.all,
                                  current: selectedFilter,
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  ref: ref,
                                  label: 'ยังไม่ชำระ (${bills.where((b) => b.status == 'unpaid').length})',
                                  filter: MyBillsFilter.unpaid,
                                  current: selectedFilter,
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  ref: ref,
                                  label: 'ชำระบางส่วน (${bills.where((b) => b.status == 'partially_paid').length})',
                                  filter: MyBillsFilter.partiallyPaid,
                                  current: selectedFilter,
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  ref: ref,
                                  label: 'ครบแล้ว (${bills.where((b) => b.status == 'paid' || b.status == 'fully_paid').length})',
                                  filter: MyBillsFilter.paid,
                                  current: selectedFilter,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Section Title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getFilterSectionTitle(selectedFilter),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                              ),
                              Text(
                                '${filteredBills.length} รายการ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Bills Contiguous List
                        if (filteredBills.isEmpty)
                          _buildEmptyState(isDark)
                        else
                          Column(
                            children: filteredBills.asMap().entries.map((entry) {
                              return AnimatedListItem(
                                index: entry.key,
                                child: _buildBillListItem(context, entry.value, isDark),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 80),
                      ],
                    );
                  },
                ),
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
  Widget _buildHeader(
    BuildContext context, {
    required WidgetRef ref,
    required bool isDark,
    required double totalBillAmount,
    required int totalBillsCount,
    required int unpaidBillsCount,
    required int totalDebtors,
  }) {
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
              // 1. Action Bar: Search Bar + Coins Points + Refresh
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        GlobalSearchSheet.show(context);
                      },
                      child: Container(
                        height: 38,
                        decoration: ShapeDecoration(
                          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.22),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 19, cornerSmoothing: 1.0),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ค้นหาบิลที่คุณสร้าง...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Coin Points Capsule
                  Consumer(
                    builder: (context, ref, _) {
                      final storeState = ref.watch(rewardStoreProvider);
                      final points = storeState.points;

                      return GestureDetector(
                        onTap: () => context.push('/rewards'),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                size: 16,
                                color: Color(0xFFFFD700),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$points',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Refresh Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.invalidate(myBillsProvider);
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 19, cornerSmoothing: 1.0),
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Financial Balance Hero
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ยอดรวมบิลทั้งหมดที่สร้าง',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedCounterText(
                        value: totalBillAmount,
                        prefix: '฿',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),

                  // Status Pill
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
                      '$totalBillsCount บิลทั้งหมด',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3. Compact Metrics Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricItem(
                      label: 'รอดำเนินการ',
                      value: '$unpaidBillsCount บิล',
                      icon: Icons.pending_actions_rounded,
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: Colors.white24,
                    ),
                    _buildMetricItem(
                      label: 'ผู้ร่วมจ่ายทั้งหมด',
                      value: '$totalDebtors คน',
                      icon: Icons.people_alt_rounded,
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

  static Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8)),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required WidgetRef ref,
    required String label,
    required MyBillsFilter filter,
    required MyBillsFilter current,
    required bool isDark,
  }) {
    final isSelected = filter == current;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(myBillsFilterProvider.notifier).state = filter;
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: ShapeDecoration(
          color: isSelected
              ? const Color(0xFFFF5000)
              : (isDark ? AppColors.surfaceTile1 : const Color(0xFFF3F4F6)),
          shape: SmoothRectangleBorder(
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
              width: 0.8,
            ),
            borderRadius: const SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.bodyMuted : AppColors.ink),
          ),
        ),
      ),
    );
  }

  String _getFilterSectionTitle(MyBillsFilter filter) {
    switch (filter) {
      case MyBillsFilter.all:
        return 'บิลที่คุณสร้างทั้งหมด';
      case MyBillsFilter.unpaid:
        return 'บิลที่ยังรอชำระ';
      case MyBillsFilter.partiallyPaid:
        return 'บิลที่ชำระแล้วบางส่วน';
      case MyBillsFilter.paid:
        return 'บิลที่ชำระครบแล้ว';
    }
  }

  Widget _buildBillListItem(BuildContext context, BillModel bill, bool isDark) {
    final dateStr = bill.createdAt != null
        ? DebtAgeCalculator.formatThaiDate(bill.createdAt!)
        : 'วันนี้';

    return Material(
      color: isDark ? AppColors.surfaceTile1 : Colors.white,
      child: InkWell(
        onTap: () => context.push('/bills/${bill.id}'),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Bill Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: ShapeDecoration(
                      color: isDark
                          ? const Color(0xFF2C2D32)
                          : const Color(0xFFFFECE5),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 13, cornerSmoothing: 0.8),
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFFF5000),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title, Date, Participant Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                (bill.title != null && bill.title!.trim().isNotEmpty)
                                    ? bill.title!
                                    : 'บิลค่าใช้จ่าย',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildStatusBadge(bill.status, isDark),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (bill.items.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${bill.items.length} ผู้ร่วมหาร',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (bill.items.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildDebtorsPreview(bill.items, isDark),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Amount & Chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            bill.totalOutstandingAmount > 0
                                ? '฿${bill.totalOutstandingAmount.toStringAsFixed(2)}'
                                : '฿${bill.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: bill.totalOutstandingAmount > 0
                                  ? const Color(0xFFFF5000)
                                  : const Color(0xFF34C759),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ],
                      ),
                      if (bill.totalOutstandingAmount > 0)
                        Text(
                          'บิลเต็ม ฿${bill.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Inset Divider
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 68,
              color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtorsPreview(List<BillItemParticipantModel> items, bool isDark) {
    const maxVisible = 4;
    final visibleItems = items.take(maxVisible).toList();

    return Row(
      children: [
        SizedBox(
          height: 22,
          width: (visibleItems.length * 16.0) + 8,
          child: Stack(
            children: List.generate(visibleItems.length, (idx) {
              final participant = visibleItems[idx];
              final debtor = participant.debtor;
              final name = debtor?.displayName ?? 'เพื่อน';
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

              return Positioned(
                left: idx * 14.0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2D32) : const Color(0xFFFFECE5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.surfaceTile1 : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF5000),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'paid':
      case 'fully_paid':
        bg = const Color(0xFF34C759).withValues(alpha: 0.12);
        fg = const Color(0xFF34C759);
        label = 'ชำระครบ';
        break;
      case 'partially_paid':
        bg = const Color(0xFFFF9500).withValues(alpha: 0.12);
        fg = const Color(0xFFFF9500);
        label = 'ชำระบางส่วน';
        break;
      case 'fully_written_off':
        bg = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
        fg = isDark ? Colors.white70 : AppColors.inkMuted80;
        label = 'ยกหนี้แล้ว';
        break;
      case 'cancelled':
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
        label = 'ยกเลิกแล้ว';
        break;
      default:
        bg = const Color(0xFFFF3B30).withValues(alpha: 0.1);
        fg = const Color(0xFFFF3B30);
        label = 'ยังไม่ชำระ';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: Color(0xFF34C759),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ไม่พบบิลในหมวดหมู่นี้',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ลองเปลี่ยนตัวกรอง หรือแตะ "+ สร้างบิลใหม่" ด้านล่าง',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          AppSkeleton(width: double.infinity, height: 38, cornerRadius: 10, margin: EdgeInsets.only(bottom: 14)),
          DebtCardSkeleton(),
          DebtCardSkeleton(),
          DebtCardSkeleton(),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'ไม่สามารถโหลดข้อมูลบิลได้',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted48),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(myBillsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('ลองใหม่อีกครั้ง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
