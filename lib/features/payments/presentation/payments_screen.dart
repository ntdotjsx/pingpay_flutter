import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/animations/animated_counter_text.dart';
import '../../../core/animations/animated_list_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../home/presentation/widgets/global_search_sheet.dart';
import '../../rewards/providers/reward_providers.dart';
import '../models/payment_models.dart';
import '../providers/payment_providers.dart';
import 'widgets/debt_acknowledgement_detail_sheet.dart';
import 'widgets/debt_card.dart';
import 'widgets/payment_detail_bottom_sheet.dart';
import 'receivables_screen.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const PaymentsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  late int _selectedPaymentTab; // 0: เราต้องจ่าย (Payable), 1: เพื่อนติดเรา (Receivable)

  @override
  void initState() {
    super.initState();
    _selectedPaymentTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtsState = ref.watch(userDebtsProvider);
    final receivablesState = ref.watch(userReceivablesProvider);
    final debtsNotifier = ref.read(userDebtsProvider.notifier);
    final receivablesNotifier = ref.read(userReceivablesProvider.notifier);

    final currentTotalAmount = _selectedPaymentTab == 0
        ? debtsState.summary.totalOutstandingAmount
        : receivablesState.summary.totalOutstandingAmount;

    final currentCount = _selectedPaymentTab == 0
        ? debtsState.summary.outstandingCount
        : receivablesState.summary.debtorCount;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceBlack
          : AppColors.canvasParchment,
      body: Column(
        children: [
          // ── 1. Signature Executive Header ─────────────────────────────────────
          _buildExecutiveHeader(
            context,
            isDark: isDark,
            debtsState: debtsState,
            receivablesState: receivablesState,
            totalAmount: currentTotalAmount,
            count: currentCount,
            onRefresh: () {
              HapticFeedback.lightImpact();
              if (_selectedPaymentTab == 0) {
                debtsNotifier.loadDebts();
              } else {
                receivablesNotifier.loadReceivables();
              }
            },
          ),

          // ── 2. Scrollable Body Content ──────────────────────────────────────────
          Expanded(
            child: _selectedPaymentTab == 0
                ? RefreshIndicator(
                    onRefresh: () => debtsNotifier.loadDebts(showLoading: false),
                    color: const Color(0xFFFF5000),
                    child: debtsState.isLoading
                        ? _buildSkeletonLoading(isDark)
                        : debtsState.errorMessage != null
                            ? _buildErrorState(context, debtsState.errorMessage!)
                            : _buildDebtsContent(context, debtsState),
                  )
                : const ReceivablesScreenBody(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TOP SIGNATURE HEADER
  // =========================================================================
  Widget _buildExecutiveHeader(
    BuildContext context, {
    required bool isDark,
    required UserDebtsState debtsState,
    required UserReceivablesState receivablesState,
    required double totalAmount,
    required int count,
    required VoidCallback onRefresh,
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
              // 1. Top Action Bar: Search Pill + Rewards Coin + Refresh
              Row(
                children: [
                  // Clickable Search Bar Squircle
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
                              'ค้นหาเพื่อน หรือบิล...',
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
                    onTap: onRefresh,
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

              // 2. Integrated Financial Balance Display
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPaymentTab == 0
                            ? 'ยอดรวมที่เราต้องชำระ'
                            : 'ยอดรวมที่เพื่อนติดเรา',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedCounterText(
                        value: totalAmount,
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
                      _selectedPaymentTab == 0
                          ? (count > 0 ? '$count รายการค้าง' : 'ไม่มีหนี้ค้าง 🎉')
                          : (count > 0 ? '$count คนค้างชำระ' : 'ไม่มีลูกหนี้ค้าง 🎉'),
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

              // 3. Frosted Segmented Switcher Pill
              Container(
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildSegmentTab(
                      label: 'เราต้องจ่าย',
                      count: debtsState.summary.outstandingCount,
                      isSelected: _selectedPaymentTab == 0,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPaymentTab = 0);
                      },
                    ),
                    _buildSegmentTab(
                      label: 'เพื่อนติดเรา',
                      count: receivablesState.summary.debtorCount,
                      isSelected: _selectedPaymentTab == 1,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPaymentTab = 1);
                      },
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
    required int count,
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
                ? (isDark ? AppColors.surfaceTile1 : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.2,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.ink)
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (count > 0 ? const Color(0xFFFF5000) : const Color(0xFF34C759))
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BODY: DEBTS LIST & FILTERS
  // =========================================================================
  Widget _buildDebtsContent(BuildContext context, UserDebtsState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredDebts = state.filteredDebts;
    final pendingDebts = state.pendingAcceptanceDebts;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 14, bottom: 28),
      children: [
        // 1. Pending Debt Requests Banner (if any)
        if (pendingDebts.isNotEmpty && state.currentFilter != DebtFilter.pendingAcceptance) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: ShapeDecoration(
                color: isDark ? const Color(0xFF2B1D0B) : const Color(0xFFFFF8E6),
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.8),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.assignment_late_outlined,
                              color: Color(0xFFFF9500),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'คำร้องขอเป็นหนี้รอการตอบรับ',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFFB340) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${pendingDebts.length} รายการ',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF9500),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'เพื่อนสร้างบิลหารเงินมา แตะที่รายการเพื่อตรวจสอบและยอมรับหนี้',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...pendingDebts.map(
                    (debt) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: InkWell(
                        onTap: () => DebtAcknowledgementDetailSheet.show(context, debt),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceTile2 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF9500).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: const Color(0xFFFF9500).withValues(alpha: 0.15),
                                child: Text(
                                  debt.creditor.displayName.isNotEmpty
                                      ? debt.creditor.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF9500),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      debt.billTitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'สร้างโดย ${debt.creditor.displayName}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '฿${debt.outstandingAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF9500),
                                    ),
                                  ),
                                  const Text(
                                    'แตะเพื่อยอมรับ >',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF9500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 2. Horizontal Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildFilterBar(context, state),
        ),

        const SizedBox(height: 14),

        // 3. Section Title with Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getFilterSectionTitle(state.currentFilter),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                ),
              ),
              Text(
                '${filteredDebts.length} รายการ',
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

        // 4. Contiguous Edge-to-Edge List (No card margin gaps)
        if (filteredDebts.isEmpty)
          _buildEmptyState(context, state.currentFilter)
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceTile1 : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
                  width: 0.5,
                ),
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFF0F2F5),
                  width: 0.5,
                ),
              ),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: filteredDebts.length,
              itemBuilder: (context, index) {
                final debt = filteredDebts[index];
                return AnimatedListItem(
                  index: index,
                  child: DebtCard(
                    debt: debt,
                    onPayTap: () {
                      if (!debt.isAcknowledged) {
                        DebtAcknowledgementDetailSheet.show(context, debt);
                      } else {
                        PaymentDetailBottomSheet.show(context, debt);
                      }
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, UserDebtsState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(userDebtsProvider.notifier);
    final pendingCount = state.pendingAcceptanceDebts.length;

    final filters = [
      {'key': DebtFilter.unpaid, 'label': 'ค้างชำระ'},
      if (pendingCount > 0)
        {'key': DebtFilter.pendingAcceptance, 'label': 'รอตอบรับ ($pendingCount)'},
      {'key': DebtFilter.partiallyPaid, 'label': 'ชำระบางส่วน'},
      {'key': DebtFilter.pendingConfirmation, 'label': 'รอยืนยัน'},
      {'key': DebtFilter.all, 'label': 'ทั้งหมด'},
      {'key': DebtFilter.history, 'label': 'ประวัติ'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final filterType = f['key'] as DebtFilter;
          final isSelected = state.currentFilter == filterType;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.setFilter(filterType);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                decoration: ShapeDecoration(
                  color: isSelected
                      ? const Color(0xFFFF5000)
                      : (isDark ? AppColors.surfaceTile1 : Colors.white),
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white10 : const Color(0xFFE2E6EC)),
                      width: 0.8,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 10, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Text(
                  f['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.bodyMuted : AppColors.ink),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFilterSectionTitle(DebtFilter filter) {
    switch (filter) {
      case DebtFilter.unpaid:
        return 'รายการค้างชำระ';
      case DebtFilter.pendingAcceptance:
        return 'คำร้องขอเป็นหนี้รอการตอบรับ';
      case DebtFilter.partiallyPaid:
        return 'รายการชำระแล้วบางส่วน';
      case DebtFilter.pendingConfirmation:
        return 'รายการที่รอยืนยัน';
      case DebtFilter.all:
        return 'รายการหนี้ทั้งหมด';
      case DebtFilter.history:
        return 'ประวัติหนี้';
    }
  }

  Widget _buildEmptyState(BuildContext context, DebtFilter filter) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
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
              Icons.check_circle_outline_rounded,
              size: 40,
              color: Color(0xFF34C759),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            filter == DebtFilter.unpaid
                ? 'ยอดเยี่ยม! คุณไม่มีหนี้ค้างชำระ'
                : 'ไม่พบรายการหนี้ในหมวดนี้',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filter == DebtFilter.unpaid
                ? 'เมื่อเพื่อนสร้างบิลหารเงิน รายการจะปรากฏที่นี่ทันที'
                : 'ลองเปลี่ยนตัวกรองเพื่อดูรายการหนี้อื่น ๆ',
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        AppSkeleton(width: double.infinity, height: 38, cornerRadius: 10, margin: EdgeInsets.only(bottom: 14)),
        DebtCardSkeleton(),
        DebtCardSkeleton(),
        DebtCardSkeleton(),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'ไม่สามารถโหลดข้อมูลหนี้สินได้',
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
              onPressed: () => ref.read(userDebtsProvider.notifier).loadDebts(),
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
