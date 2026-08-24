import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/animations/animated_list_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../models/payment_models.dart';
import '../providers/payment_providers.dart';
import 'widgets/debt_acknowledgement_detail_sheet.dart';
import 'widgets/debt_card.dart';
import 'widgets/payment_detail_bottom_sheet.dart';
import 'widgets/payment_summary_card.dart';
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'การเงินและหนี้สิน',
          style: TextStyle(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'รีเฟรชยอดหนี้',
            onPressed: () {
              HapticFeedback.lightImpact();
              if (_selectedPaymentTab == 0) {
                debtsNotifier.loadDebts();
              } else {
                receivablesNotifier.loadReceivables();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── 1. Apple/Revolut Segmented Switcher (เราต้องจ่าย vs เพื่อนติดเรา) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 46,
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceTile2 : const Color(0xFFE5E8EE),
                borderRadius: BorderRadius.circular(14),
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
          ),

          // ── 2. Body Content depending on selected tab ──────────────────
          Expanded(
            child: _selectedPaymentTab == 0
                ? RefreshIndicator(
                    onRefresh: () => debtsNotifier.loadDebts(showLoading: false),
                    color: const Color(0xFFFF5000),
                    child: debtsState.isLoading
                        ? _buildSkeletonLoading(isDark)
                        : debtsState.errorMessage != null
                            ? _buildErrorState(context, debtsState.errorMessage!)
                            : _buildContent(context, debtsState),
                  )
                : const ReceivablesScreenBody(),
          ),
        ],
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
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
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
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.2,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.ink)
                      : (isDark ? AppColors.bodyMuted : AppColors.inkMuted48),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (count > 0
                          ? const Color(0xFFFF5000)
                          : const Color(0xFF34C759))
                      : (isDark ? Colors.white10 : Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserDebtsState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredDebts = state.filteredDebts;
    final pendingDebts = state.pendingAcceptanceDebts;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // 1. Payment Summary Card (Header)
        PaymentSummaryCard(
          outstandingCount: state.summary.outstandingCount,
          totalOutstandingAmount: state.summary.totalOutstandingAmount,
          currency: state.summary.currency,
          onRefresh: () => ref.read(userDebtsProvider.notifier).loadDebts(),
        ),

        // 2. Pending Debt Requests Callout
        if (pendingDebts.isNotEmpty && state.currentFilter != DebtFilter.pendingAcceptance) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: isDark ? const Color(0xFF2B1D0B) : const Color(0xFFFFF8E6),
              shape: const SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.8),
                ),
              ),
              shadows: [
                BoxShadow(
                  color: const Color(0xFFFF9500).withValues(alpha: isDark ? 0.08 : 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_late_outlined,
                            color: Color(0xFFFF9500),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'คำร้องขอเป็นหนี้รอการตอบรับ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFFFB340) : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingDebts.length} รายการ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
                    fontSize: 12,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted80,
                  ),
                ),
                const SizedBox(height: 12),
                ...pendingDebts.map(
                  (debt) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () => DebtAcknowledgementDetailSheet.show(context, debt),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceTile2 : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFFF9500).withValues(alpha: 0.15),
                              child: Text(
                                debt.creditor.displayName.isNotEmpty
                                    ? debt.creditor.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF9500),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    debt.billTitle,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFF9500),
                                  ),
                                ),
                                const Text(
                                  'แตะเพื่อยอมรับ >',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
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
        ],

        const SizedBox(height: 18),

        // 3. Horizontal Filter Chips Bar
        _buildFilterBar(context, state),

        const SizedBox(height: 16),

        // 4. Section Title with Count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getFilterSectionTitle(state.currentFilter),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            Text(
              '${filteredDebts.length} รายการ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 5. Debt List or Empty State
        if (filteredDebts.isEmpty)
          _buildEmptyState(context, state.currentFilter)
        else
          ...filteredDebts.asMap().entries.map(
            (entry) => AnimatedListItem(
              index: entry.key,
              child: DebtCard(
                debt: entry.value,
                onPayTap: () {
                  if (!entry.value.isAcknowledged) {
                    DebtAcknowledgementDetailSheet.show(context, entry.value);
                  } else {
                    PaymentDetailBottomSheet.show(context, entry.value);
                  }
                },
              ),
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
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.setFilter(filterType);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: ShapeDecoration(
                  color: isSelected
                      ? const Color(0xFFFF5000)
                      : (isDark ? AppColors.surfaceTile1 : Colors.white),
                  shadows: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF5000).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white10 : const Color(0xFFE2E6EC)),
                      width: 1,
                    ),
                    borderRadius: const SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 14, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Text(
                  f['label'] as String,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
        return 'รายการค้างชำระ (Actionable Debts)';
      case DebtFilter.pendingAcceptance:
        return 'คำร้องขอเป็นหนี้รอการตอบรับ';
      case DebtFilter.partiallyPaid:
        return 'รายการชำระแล้วบางส่วน';
      case DebtFilter.pendingConfirmation:
        return 'รายการที่รอเจ้าของบิลยืนยัน';
      case DebtFilter.all:
        return 'รายการหนี้ทั้งหมด';
      case DebtFilter.history:
        return 'ประวัติหนี้ที่ชำระครบแล้ว / ยกหนี้';
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: Color(0xFF34C759),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filter == DebtFilter.unpaid
                ? 'ยอดเยี่ยม! คุณไม่มีหนี้ค้างชำระ'
                : 'ไม่พบรายการหนี้ในหมวดนี้',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
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
        AppSkeleton(width: double.infinity, height: 110, cornerRadius: 22, margin: EdgeInsets.only(bottom: 16)),
        AppSkeleton(width: double.infinity, height: 44, cornerRadius: 14, margin: EdgeInsets.only(bottom: 16)),
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
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'ไม่สามารถโหลดข้อมูลหนี้สินได้',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted48),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(userDebtsProvider.notifier).loadDebts(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('ลองใหม่อีกครั้ง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
