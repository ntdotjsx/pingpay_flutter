import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bills/models/bill_models.dart';
import '../../bills/providers/bill_provider.dart';
import '../../payments/providers/payment_providers.dart';
import '../models/monthly_summary_model.dart';
import '../models/yearly_summary_model.dart';

enum AnalyticsPeriodType { monthly, yearly }

/// Provider for toggling between Monthly and Yearly view
final analyticsPeriodTypeProvider = StateProvider<AnalyticsPeriodType>((ref) {
  return AnalyticsPeriodType.monthly;
});

/// Provider for the selected year
final selectedYearProvider = StateProvider<int>((ref) {
  return DateTime.now().year;
});

/// Provider computing full annual financial metrics and breakdown for the selected year
final yearlyAnalyticsProvider = Provider<YearlyExpenseSummary>((ref) {
  final targetYear = ref.watch(selectedYearProvider);

  final billsAsync = ref.watch(myBillsProvider);
  final allBills = (billsAsync.valueOrNull ?? [])
      .where((b) => !b.isCancelled && !b.isFullyWrittenOff)
      .toList();

  final debtsState = ref.watch(userDebtsProvider);
  final allDebts = debtsState.allDebts
      .where((d) => d.status != 'cancelled' && d.status != 'written_off')
      .toList();

  // 1. Filter bills created in the selected year
  final yearlyBills = allBills.where((b) {
    if (b.createdAt == null) return false;
    return b.createdAt!.year == targetYear;
  }).toList();

  yearlyBills.sort((a, b) {
    final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  });

  // Calculate totals for the year
  final totalCreatedBills = yearlyBills.fold<double>(
    0.0,
    (acc, b) => acc + b.totalAmount,
  );

  final totalReceivablesCollected = yearlyBills.fold<double>(
    0.0,
    (acc, b) => acc + b.totalPaidAmount,
  );

  final pendingReceivables = yearlyBills.fold<double>(
    0.0,
    (acc, b) => acc + b.totalOutstandingAmount,
  );

  final yearlyDebts = allDebts.where((d) {
    return d.debtStartDate.year == targetYear;
  }).toList();

  final totalDebtsPaid = yearlyDebts.fold<double>(
    0.0,
    (acc, d) => acc + d.amountPaid,
  );

  final totalOutflow = totalCreatedBills + totalDebtsPaid;
  final totalInflow = totalReceivablesCollected;
  final totalBillsCount = yearlyBills.length;
  final totalSettledCount = yearlyBills.where((b) => b.isFullySettled).length;

  const monthNames = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  // 2. Compute 12-month data points for the year
  final monthlyTrend = List.generate(12, (index) {
    final m = index + 1;

    final billsForM = allBills.where((b) {
      if (b.createdAt == null) return false;
      return b.createdAt!.year == targetYear && b.createdAt!.month == m;
    });

    final createdForM = billsForM.fold<double>(0.0, (acc, b) => acc + b.totalAmount);
    final inflowForM = billsForM.fold<double>(0.0, (acc, b) => acc + b.totalPaidAmount);

    final debtsForM = allDebts.where((d) {
      return d.debtStartDate.year == targetYear && d.debtStartDate.month == m;
    });
    final debtsPaidForM = debtsForM.fold<double>(0.0, (acc, d) => acc + d.amountPaid);

    return MonthlyDataPoint(
      month: m,
      monthName: monthNames[index],
      outflow: createdForM + debtsPaidForM,
      inflow: inflowForM,
    );
  });

  // Calculate average monthly expense (across active months or 12 months)
  final averageMonthlyExpense = totalOutflow > 0 ? (totalOutflow / 12.0) : 0.0;

  // Find peak spending month
  MonthlyDataPoint? peakMonth;
  for (final dp in monthlyTrend) {
    if (dp.outflow > 0) {
      if (peakMonth == null || dp.outflow > peakMonth.outflow) {
        peakMonth = dp;
      }
    }
  }

  // 3. Compute Category Breakdown for the entire year
  final categoryBreakdown = <MonthlyCategoryBreakdown>[];
  if (totalOutflow > 0) {
    if (totalCreatedBills > 0) {
      categoryBreakdown.add(
        MonthlyCategoryBreakdown(
          title: 'บิลที่ออกเงินไปก่อนทั้งปี',
          amount: totalCreatedBills,
          percentage: (totalCreatedBills / totalOutflow) * 100.0,
          colorValue: 0xFFFF5000,
        ),
      );
    }
    if (totalDebtsPaid > 0) {
      categoryBreakdown.add(
        MonthlyCategoryBreakdown(
          title: 'จ่ายหนี้คืนเพื่อนทั้งปี',
          amount: totalDebtsPaid,
          percentage: (totalDebtsPaid / totalOutflow) * 100.0,
          colorValue: 0xFF2563EB,
        ),
      );
    }
    if (totalReceivablesCollected > 0) {
      categoryBreakdown.add(
        MonthlyCategoryBreakdown(
          title: 'ได้รับเงินคืนแล้วทั้งปี',
          amount: totalReceivablesCollected,
          percentage: (totalReceivablesCollected / totalOutflow) * 100.0,
          colorValue: 0xFF10B981,
        ),
      );
    }
  }

  return YearlyExpenseSummary(
    year: targetYear,
    totalOutflow: totalOutflow,
    totalInflow: totalInflow,
    totalCreatedBillsAmount: totalCreatedBills,
    totalDebtsPaidAmount: totalDebtsPaid,
    totalReceivablesCollected: totalReceivablesCollected,
    pendingReceivablesAmount: pendingReceivables,
    totalBillsCount: totalBillsCount,
    totalSettledCount: totalSettledCount,
    averageMonthlyExpense: averageMonthlyExpense,
    peakSpendingMonth: peakMonth,
    monthlyTrend: monthlyTrend,
    yearlyBills: yearlyBills,
    categoryBreakdown: categoryBreakdown,
  );
});
