import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/payment_providers.dart';
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
      backgroundColor: isDark
          ? AppColors.surfaceBlack
          : AppColors.canvasParchment,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'การเงินและหนี้สิน',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_selectedPaymentTab == 0) {
                debtsNotifier.loadDebts();
              } else {
                receivablesNotifier.loadReceivables();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Control: [ เราต้องจ่าย ] vs [ เพื่อนติดเรา ]
          Container(
            color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceTile2
                    : AppColors.canvasParchment,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : AppColors.hairline,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPaymentTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedPaymentTab == 0
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'เราต้องจ่าย (${debtsState.summary.outstandingCount})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedPaymentTab == 0
                                ? Colors.white
                                : (isDark
                                      ? AppColors.bodyMuted
                                      : AppColors.ink),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPaymentTab = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedPaymentTab == 1
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'เพื่อนติดเรา (${receivablesState.summary.debtorCount})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedPaymentTab == 1
                                ? Colors.white
                                : (isDark
                                      ? AppColors.bodyMuted
                                      : AppColors.ink),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body Content depending on selected tab
          Expanded(
            child: _selectedPaymentTab == 0
                ? RefreshIndicator(
                    onRefresh: () =>
                        debtsNotifier.loadDebts(showLoading: false),
                    color: AppColors.primary,
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

  Widget _buildContent(BuildContext context, UserDebtsState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredDebts = state.filteredDebts;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // 1. Payment Summary Card (Header)
        PaymentSummaryCard(
          outstandingCount: state.summary.outstandingCount,
          totalOutstandingAmount: state.summary.totalOutstandingAmount,
          currency: state.summary.currency,
          onRefresh: () => ref.read(userDebtsProvider.notifier).loadDebts(),
        ),

        const SizedBox(height: 18),

        // 2. Filter Tabs & Sorting Chips
        _buildFilterBar(context, state),

        const SizedBox(height: 14),

        // 3. Section Title with Count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getFilterSectionTitle(state.currentFilter),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              ),
            ),
            Text(
              '${filteredDebts.length} รายการ',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted48,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 4. Debt List or Empty State
        if (filteredDebts.isEmpty)
          _buildEmptyState(context, state.currentFilter)
        else
          ...filteredDebts.map(
            (debt) => DebtCard(
              debt: debt,
              onPayTap: () => PaymentDetailBottomSheet.show(context, debt),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, UserDebtsState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(userDebtsProvider.notifier);

    final filters = [
      {'key': DebtFilter.unpaid, 'label': 'ค้างชำระ'},
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
            child: ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) notifier.setFilter(filterType);
              },
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.surfaceTile2
                  : AppColors.canvas,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.bodyMuted : AppColors.ink),
              ),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white10 : AppColors.hairline),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filter == DebtFilter.unpaid
                ? 'ไม่มีรายการค้างชำระ'
                : 'ไม่พบรายการหนี้ในหมวดหมู่นี้',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filter == DebtFilter.unpaid
                ? 'ตอนนี้คุณไม่มีหนี้ที่ต้องชำระ ยอดเยี่ยมมาก!'
                : 'คุณสามารถตรวจสอบหมวดหมู่อื่นได้จากแท็บด้านบน',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.inkMuted48),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('กลับหน้าหลัก'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'ไม่สามารถโหลดรายการค้างชำระได้',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted48),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.read(userDebtsProvider.notifier).loadDebts(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Skeleton
        Container(
          height: 140,
          decoration: ShapeDecoration(
            color: isDark ? AppColors.surfaceTile1 : Colors.white,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.all(
                SmoothRadius(cornerRadius: 22, cornerSmoothing: 1.0),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Debt Cards Skeleton
        ...List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 130,
            decoration: ShapeDecoration(
              color: isDark ? AppColors.surfaceTile1 : Colors.white,
              shape: const SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 20, cornerSmoothing: 1.0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
