import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/theme.dart';
import '../models/yearly_summary_model.dart';
import '../providers/monthly_analytics_provider.dart';
import '../providers/yearly_analytics_provider.dart';
import 'widgets/monthly_bar_chart.dart';
import 'widgets/monthly_breakdown_card.dart';
import 'widgets/monthly_bill_tile.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/line_share_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../../friends/providers/friend_nickname_provider.dart';

class MonthlySummaryScreen extends ConsumerWidget {
  const MonthlySummaryScreen({super.key});

  static const List<String> _thaiMonthsFull = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodType = ref.watch(analyticsPeriodTypeProvider);
    final selectedPeriod = ref.watch(selectedMonthlyPeriodProvider);
    final selectedYear = ref.watch(selectedYearProvider);

    final monthlySummary = ref.watch(monthlyAnalyticsProvider);
    final yearlySummary = ref.watch(yearlyAnalyticsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat('#,##0.00', 'th');

    final currentUserId = ref.watch(authStateProvider).user?.id;
    final nicknamesMap = ref.watch(friendNicknameProvider);

    final monthName = _thaiMonthsFull[selectedPeriod.month - 1];
    final yearThai = (periodType == AnalyticsPeriodType.monthly ? selectedPeriod.year : selectedYear) + 543;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceBlack : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 1. Signature PingPay Executive Gradient Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const ShapeDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF5000),
                    Color(0xFFFF6A00),
                    Color(0xFFFF8500),
                  ],
                ),
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.only(
                    bottomLeft: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
                    bottomRight: SmoothRadius(cornerRadius: 28, cornerSmoothing: 0.8),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                  child: Column(
                    children: [
                      // Top Bar: Back Button, Title, and Mode Switcher
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
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
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: () => context.pop(),
                            ),
                          ),
                          Text(
                            periodType == AnalyticsPeriodType.monthly
                                ? 'สรุปค่าใช้จ่ายรายเดือน'
                                : 'สรุปค่าใช้จ่ายรายปี',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Builder(
                            builder: (ctx) {
                              final isCurrentOrFutureYear = selectedYear >= DateTime.now().year;
                              final isYearlyUnfinished = periodType == AnalyticsPeriodType.yearly && isCurrentOrFutureYear;

                              return Opacity(
                                opacity: isYearlyUnfinished ? 0.35 : 1.0,
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
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.share_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    tooltip: isYearlyUnfinished
                                        ? 'สรุปรายปียังไม่พร้อมให้ส่ง (ยังไม่สิ้นปี)'
                                        : 'แชร์สรุปรายการ',
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      if (isYearlyUnfinished) {
                                        AppToast.warning(
                                          context,
                                          'ยังไม่สามารถส่งสรุปรายปีได้ เนื่องจากยังไม่สิ้นสุดปี พ.ศ. $yearThai',
                                          title: 'ยังไม่ถึงกำหนดส่งรายปี',
                                        );
                                        return;
                                      }

                                      if (periodType == AnalyticsPeriodType.monthly) {
                                        LineShareHelper.shareSummary(
                                          context: context,
                                          periodTitle: 'ประจำเดือน $monthName $yearThai',
                                          totalOutflow: monthlySummary.totalOutflow,
                                          totalInflow: monthlySummary.totalInflow,
                                          totalBillsCount: monthlySummary.totalBillsCount,
                                          bills: monthlySummary.monthlyBills,
                                          paidDebts: monthlySummary.monthlyPaidDebts,
                                          currentUserId: currentUserId,
                                          nicknamesMap: nicknamesMap,
                                        );
                                      } else {
                                        LineShareHelper.shareSummary(
                                          context: context,
                                          periodTitle: 'ประจำปี พ.ศ. $yearThai ($selectedYear)',
                                          totalOutflow: yearlySummary.totalOutflow,
                                          totalInflow: yearlySummary.totalInflow,
                                          totalBillsCount: yearlySummary.totalBillsCount,
                                          bills: yearlySummary.yearlyBills,
                                          currentUserId: currentUserId,
                                          nicknamesMap: nicknamesMap,
                                          averageMonthlyExpense: yearlySummary.averageMonthlyExpense,
                                          peakSpendingMonth: yearlySummary.peakSpendingMonth != null
                                              ? '${yearlySummary.peakSpendingMonth!.monthName} (฿${currencyFormatter.format(yearlySummary.peakSpendingMonth!.outflow)})'
                                              : null,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // View Mode Toggle Segmented Capsule (รายเดือน | รายปี)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: ShapeDecoration(
                          color: Colors.black.withValues(alpha: 0.16),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.8),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildModeTab(
                              label: '📅 สรุปรายเดือน',
                              isSelected: periodType == AnalyticsPeriodType.monthly,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref.read(analyticsPeriodTypeProvider.notifier).state =
                                    AnalyticsPeriodType.monthly;
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildModeTab(
                              label: '📊 สรุปรายปี',
                              isSelected: periodType == AnalyticsPeriodType.yearly,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref.read(analyticsPeriodTypeProvider.notifier).state =
                                    AnalyticsPeriodType.yearly;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Period Navigator Capsule (< มีนาคม 2569 > หรือ < ปี 2569 >)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: ShapeDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 24, cornerSmoothing: 1.0),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                if (periodType == AnalyticsPeriodType.monthly) {
                                  final prevMonth = DateTime(
                                    selectedPeriod.year,
                                    selectedPeriod.month - 1,
                                    1,
                                  );
                                  ref.read(selectedMonthlyPeriodProvider.notifier).state = prevMonth;
                                  ref.read(selectedYearProvider.notifier).state = prevMonth.year;
                                } else {
                                  ref.read(selectedYearProvider.notifier).state = selectedYear - 1;
                                  ref.read(selectedMonthlyPeriodProvider.notifier).state = DateTime(
                                    selectedYear - 1,
                                    selectedPeriod.month,
                                    1,
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              periodType == AnalyticsPeriodType.monthly
                                  ? '$monthName $yearThai'
                                  : 'ปี พ.ศ. $yearThai (${selectedYear})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                if (periodType == AnalyticsPeriodType.monthly) {
                                  final nextMonth = DateTime(
                                    selectedPeriod.year,
                                    selectedPeriod.month + 1,
                                    1,
                                  );
                                  ref.read(selectedMonthlyPeriodProvider.notifier).state = nextMonth;
                                  ref.read(selectedYearProvider.notifier).state = nextMonth.year;
                                } else {
                                  ref.read(selectedYearProvider.notifier).state = selectedYear + 1;
                                  ref.read(selectedMonthlyPeriodProvider.notifier).state = DateTime(
                                    selectedYear + 1,
                                    selectedPeriod.month,
                                    1,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Hero Total Spending Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: ShapeDecoration(
                          color: isDark ? AppColors.surfaceTile1 : Colors.white,
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 22, cornerSmoothing: 1.0),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  periodType == AnalyticsPeriodType.monthly
                                      ? 'ยอดใช้จ่ายรวมประจำเดือน'
                                      : 'ยอดใช้จ่ายรวมตลอดทั้งปี',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '฿${currencyFormatter.format(periodType == AnalyticsPeriodType.monthly ? monthlySummary.totalOutflow : yearlySummary.totalOutflow)}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: ShapeDecoration(
                                color: const Color(0xFFFF5000).withValues(alpha: 0.12),
                                shape: const SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius.all(
                                    SmoothRadius(cornerRadius: 12, cornerSmoothing: 0.8),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.receipt_rounded,
                                    size: 16,
                                    color: Color(0xFFFF5000),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    periodType == AnalyticsPeriodType.monthly
                                        ? '${monthlySummary.totalBillsCount} บิล'
                                        : '${yearlySummary.totalBillsCount} บิลทั้งปี',
                                    style: const TextStyle(
                                      color: Color(0xFFFF5000),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Main Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 12-Month Spending Trend Bar Chart
                  MonthlyBarChart(
                    dataPoints: periodType == AnalyticsPeriodType.monthly
                        ? monthlySummary.annualTrend
                        : yearlySummary.monthlyTrend,
                    selectedMonth: periodType == AnalyticsPeriodType.monthly
                        ? monthlySummary.month
                        : 0, // 0 for highlighting all/none in yearly view
                    onMonthSelected: (newMonth) {
                      ref.read(selectedMonthlyPeriodProvider.notifier).state = DateTime(
                        selectedYear,
                        newMonth,
                        1,
                      );
                      if (periodType == AnalyticsPeriodType.yearly) {
                        // Switch to that month on tap
                        ref.read(analyticsPeriodTypeProvider.notifier).state =
                            AnalyticsPeriodType.monthly;
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Yearly Insights Cards (when in Yearly mode)
                  if (periodType == AnalyticsPeriodType.yearly) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildInsightCard(
                            context,
                            title: 'เฉลี่ยต่อเดือน',
                            value: '฿${currencyFormatter.format(yearlySummary.averageMonthlyExpense)}',
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFFFF5000),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInsightCard(
                            context,
                            title: 'เดือนจ่ายสูงสุด',
                            value: yearlySummary.peakSpendingMonth != null
                                ? '${yearlySummary.peakSpendingMonth!.monthName} (฿${NumberFormat('#,##0', 'th').format(yearlySummary.peakSpendingMonth!.outflow)})'
                                : 'ไม่มีค่าใช้จ่าย',
                            icon: Icons.emoji_events_rounded,
                            iconColor: const Color(0xFFFFB800),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 4-Card Quick Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: periodType == AnalyticsPeriodType.monthly ? 'ออกเงินไปก่อน' : 'ออกเงินไปก่อนทั้งปี',
                          amount: periodType == AnalyticsPeriodType.monthly
                              ? monthlySummary.totalCreatedBillsAmount
                              : yearlySummary.totalCreatedBillsAmount,
                          icon: Icons.upload_rounded,
                          color: const Color(0xFFFF5000),
                          isDark: isDark,
                          formatter: currencyFormatter,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: periodType == AnalyticsPeriodType.monthly ? 'จ่ายหนี้เพื่อน' : 'จ่ายหนี้เพื่อนทั้งปี',
                          amount: periodType == AnalyticsPeriodType.monthly
                              ? monthlySummary.totalDebtsPaidAmount
                              : yearlySummary.totalDebtsPaidAmount,
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF2563EB),
                          isDark: isDark,
                          formatter: currencyFormatter,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: periodType == AnalyticsPeriodType.monthly ? 'ได้รับเงินคืนแล้ว' : 'ได้รับเงินคืนแล้วทั้งปี',
                          amount: periodType == AnalyticsPeriodType.monthly
                              ? monthlySummary.totalReceivablesCollected
                              : yearlySummary.totalReceivablesCollected,
                          icon: Icons.call_received_rounded,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                          formatter: currencyFormatter,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: periodType == AnalyticsPeriodType.monthly ? 'รอเพื่อนคืนเงิน' : 'รอเพื่อนคืนเงินทั้งปี',
                          amount: periodType == AnalyticsPeriodType.monthly
                              ? monthlySummary.pendingReceivablesAmount
                              : yearlySummary.pendingReceivablesAmount,
                          icon: Icons.hourglass_top_rounded,
                          color: const Color(0xFFFF9500),
                          isDark: isDark,
                          formatter: currencyFormatter,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Financial Proportions Breakdown Card
                  if (periodType == AnalyticsPeriodType.monthly)
                    MonthlyBreakdownCard(summary: monthlySummary)
                  else
                    MonthlyBreakdownCard.yearly(yearlySummary: yearlySummary),

                  const SizedBox(height: 24),

                  // Section Title: Bills List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        periodType == AnalyticsPeriodType.monthly
                            ? 'รายการบิลในเดือนนี้ (${monthlySummary.monthlyBills.length})'
                            : 'รายการบิลตลอดทั้งปี (${yearlySummary.yearlyBills.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if ((periodType == AnalyticsPeriodType.monthly
                              ? monthlySummary.monthlyBills
                              : yearlySummary.yearlyBills)
                          .isNotEmpty)
                        Text(
                          'แตะเพื่อดูรายละเอียด',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Bills List
                  if (periodType == AnalyticsPeriodType.monthly) ...[
                    if (monthlySummary.monthlyBills.isEmpty)
                      _buildEmptyBillsState(context, 'ไม่มีรายการบิลในเดือน$monthName', isDark)
                    else
                      ...monthlySummary.monthlyBills.map((bill) => MonthlyBillTile(bill: bill)),
                  ] else ...[
                    if (yearlySummary.yearlyBills.isEmpty)
                      _buildEmptyBillsState(context, 'ไม่มีรายการบิลในปี พ.ศ. $yearThai', isDark)
                    else
                      ...yearlySummary.yearlyBills.map((bill) => MonthlyBillTile(bill: bill)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: ShapeDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.8),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFFFF5000) : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isDark,
    required NumberFormat formatter,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 18, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: ShapeDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: const SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.all(
                      SmoothRadius(cornerRadius: 8, cornerSmoothing: 0.8),
                    ),
                  ),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '฿${formatter.format(amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBillsState(BuildContext context, String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: ShapeDecoration(
        color: isDark ? AppColors.surfaceTile1 : Colors.white,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 22, cornerSmoothing: 0.8),
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 26,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.bodyOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เมื่อสร้างบิล รายการและสถิติจะแสดงที่นี่โดยอัตโนมัติ',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.bodyMuted : AppColors.inkMuted48,
            ),
          ),
        ],
      ),
    );
  }
}
