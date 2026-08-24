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
import '../../payments/services/debt_age_calculator.dart';
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
                // ── 1. On-Theme Signature Gradient Header & Analytics ───────
                billsAsync.when(
                  loading: () => _buildHeader(
                    context,
                    ref: ref,
                    isDark: isDark,
                    totalBillAmount: 0,
                    totalPaid: 0,
                    totalOutstanding: 0,
                    totalBillsCount: 0,
                    unpaidBillsCount: 0,
                    paidBillsCount: 0,
                    totalDebtors: 0,
                  ),
                  error: (_, __) => _buildHeader(
                    context,
                    ref: ref,
                    isDark: isDark,
                    totalBillAmount: 0,
                    totalPaid: 0,
                    totalOutstanding: 0,
                    totalBillsCount: 0,
                    unpaidBillsCount: 0,
                    paidBillsCount: 0,
                    totalDebtors: 0,
                  ),
                  data: (allBills) {
                    final currentUserId = ref.read(authStateProvider).user?.id;
                    final bills = allBills.where((b) => b.ownerId == currentUserId).toList();
                    final totalBillAmount = bills.fold(0.0, (acc, b) => acc + b.totalAmount);
                    final totalOutstanding = bills.fold(0.0, (acc, b) => acc + b.totalOutstandingAmount);
                    final totalPaid = bills.fold(0.0, (acc, b) => acc + b.totalPaidAmount);

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
                    final fullyPaidBillsCount = bills.where((b) => b.isFullyPaid).length;

                    return _buildHeader(
                      context,
                      ref: ref,
                      isDark: isDark,
                      totalBillAmount: totalBillAmount,
                      totalPaid: totalPaid,
                      totalOutstanding: totalOutstanding,
                      totalBillsCount: bills.length,
                      unpaidBillsCount: unpaidBillsCount,
                      paidBillsCount: fullyPaidBillsCount,
                      totalDebtors: totalDebtors,
                    );
                  },
                ),

                // ── 2. Content Section (Filters + List) ──────────────────────
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
                                  label: 'ยังไม่ชำระ (${bills.where((b) => b.status == 'unpaid' && !b.isCancelled && !b.isFullyWrittenOff).length})',
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

                        const SizedBox(height: 8),

                        // Bills Contiguous Edge-to-Edge List
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
  // ON-THEME EXECUTIVE HEADER & CASHFLOW INSIGHTS
  // =========================================================================
  Widget _buildHeader(
    BuildContext context, {
    required WidgetRef ref,
    required bool isDark,
    required double totalBillAmount,
    required double totalPaid,
    required double totalOutstanding,
    required int totalBillsCount,
    required int unpaidBillsCount,
    required int paidBillsCount,
    required int totalDebtors,
  }) {
    final progress = totalBillAmount > 0 ? (totalPaid / totalBillAmount).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();

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
              // 1. Header Title & Quick Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'บิลของฉัน',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'ติดตามสถานะการเรียกเก็บเงิน',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),

                  // Quick Create Button in Frosted Style
                  InkWell(
                    onTap: () => _handleCreateBill(context, ref),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'สร้างบิล',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Financial Balance Display
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

                  // Total Bills Status Pill
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

              const SizedBox(height: 12),

              // 3. Collection Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4.5,
                  backgroundColor: Colors.black.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),

              const SizedBox(height: 6),

              // Progress Text Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'เก็บได้แล้ว ฿${totalPaid.toStringAsFixed(2)} ($percent%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  Text(
                    'รอเก็บ ฿${totalOutstanding.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 4. Compact Frosted Metrics Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildFrostedMetricItem(
                      icon: Icons.pending_actions_rounded,
                      label: 'รอชำระ',
                      value: '$unpaidBillsCount บิล',
                    ),
                    Container(width: 1, height: 18, color: Colors.white24),
                    _buildFrostedMetricItem(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'จบแล้ว',
                      value: '$paidBillsCount บิล',
                    ),
                    Container(width: 1, height: 18, color: Colors.white24),
                    _buildFrostedMetricItem(
                      icon: Icons.people_outline_rounded,
                      label: 'ผู้ร่วมหาร',
                      value: '$totalDebtors คน',
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

  static Widget _buildFrostedMetricItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
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

  // =========================================================================
  // RECEIPT-STYLE CONTIGUOUS LIST ITEM
  // =========================================================================
  Widget _buildBillListItem(BuildContext context, BillModel bill, bool isDark) {
    final dateStr = bill.createdAt != null
        ? DebtAgeCalculator.formatThaiDate(bill.createdAt!)
        : 'วันนี้';

    final paidDebtorsCount = bill.items.where((i) => i.isFullyPaid).length;
    final totalDebtorsCount = bill.items.length;

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
                  // Receipt Squircle Icon
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

                  // Center: Title, Date, Split Progress
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
                            if (totalDebtorsCount > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• $paidDebtorsCount/$totalDebtorsCount จ่ายแล้ว',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: paidDebtorsCount == totalDebtorsCount
                                      ? const Color(0xFF34C759)
                                      : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                                  fontWeight: FontWeight.w500,
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

                  // Right: Total Amount & Chevron
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
              final isPaid = participant.isFullyPaid;

              return Positioned(
                left: idx * 14.0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFF34C759).withValues(alpha: 0.18)
                        : (isDark ? const Color(0xFF2C2D32) : const Color(0xFFFFECE5)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.surfaceTile1 : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isPaid ? const Color(0xFF34C759) : const Color(0xFFFF5000),
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
            'ลองเปลี่ยนตัวกรอง หรือแตะ "+ สร้างบิล" ด้านบน',
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
