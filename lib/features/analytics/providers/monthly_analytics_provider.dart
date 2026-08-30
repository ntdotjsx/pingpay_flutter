import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bills/models/bill_models.dart';
import '../../bills/providers/bill_provider.dart';
import '../../payments/providers/payment_providers.dart';
import '../models/monthly_summary_model.dart';

/// Provider for the currently selected month and year
final selectedMonthlyPeriodProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Main analytics provider computing monthly expense, inflow, outflow, and trends
final monthlyAnalyticsProvider = Provider<MonthlyExpenseSummary>((ref) {
  final selectedPeriod = ref.watch(selectedMonthlyPeriodProvider);
  final targetYear = selectedPeriod.year;
  final targetMonth = selectedPeriod.month;

  final authState = ref.watch(authStateProvider);
  final currentUserId = authState.user?.id;

  final billsAsync = ref.watch(myBillsProvider);
  final allBills = (billsAsync.valueOrNull ?? [])
      .where((b) => !b.isCancelled && !b.isFullyWrittenOff)
      .toList();

  final debtsState = ref.watch(userDebtsProvider);
  final allDebts = debtsState.allDebts
      .where((d) => d.status != 'cancelled' && d.status != 'written_off')
      .toList();

  // 1. Filter bills created in the selected month
  final monthlyBills = allBills.where((b) {
    if (b.createdAt == null) return false;
    return b.createdAt!.year == targetYear && b.createdAt!.month == targetMonth;
  }).toList();

  // Sort monthly bills descending by date
  monthlyBills.sort((a, b) {
    final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  });

  // Calculate total created bills amount for target month
  final totalCreatedBills = monthlyBills.fold<double>(
    0.0,
    (acc, b) => acc + b.totalAmount,
  );

  // Total receivables collected from friends for bills created in this month
  final totalReceivablesCollected = monthlyBills.fold<double>(
    0.0,
    (acc, b) => acc + b.totalPaidAmount,
  );

  // Pending receivables amount for bills created in this month
  final pendingReceivables = monthlyBills.fold<double>(
    0.0,
    (acc, b) => acc + b.totalOutstandingAmount,
  );

  // Debts user paid to friends in the selected month
  final monthlyDebts = allDebts.where((d) {
    return d.debtStartDate.year == targetYear && d.debtStartDate.month == targetMonth;
  }).toList();

  final monthlyPaidDebts = monthlyDebts.where((d) => d.amountPaid > 0).toList();

  final totalDebtsPaid = monthlyDebts.fold<double>(
    0.0,
    (acc, d) => acc + d.amountPaid,
  );

  // Total Outflow (Created Bills + Debts Paid to friends)
  final totalOutflow = totalCreatedBills + totalDebtsPaid;

  // Total Inflow (Receivables Collected from friends)
  final totalInflow = totalReceivablesCollected;

  // Total bills count and settled count
  final totalBillsCount = monthlyBills.length;
  final totalSettledCount = monthlyBills.where((b) => b.isFullySettled).length;

  // 2. Compute 12-Month Annual Trend for the target year
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

  final annualTrend = List.generate(12, (index) {
    final m = index + 1;

    // Filter bills for month m in targetYear
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

  // 3. Compute Category Breakdown for the selected month
  final categoryBreakdown = <MonthlyCategoryBreakdown>[];
  if (totalOutflow > 0) {
    if (totalCreatedBills > 0) {
      categoryBreakdown.add(
        MonthlyCategoryBreakdown(
          title: 'บิลที่ออกเงินไปก่อน',
          amount: totalCreatedBills,
          percentage: (totalCreatedBills / totalOutflow) * 100.0,
          colorValue: 0xFFFF5000, // PingPay Signature Orange
        ),
      );
    }
    if (totalDebtsPaid > 0) {
      categoryBreakdown.add(
        MonthlyCategoryBreakdown(
          title: 'จ่ายหนี้คืนเพื่อน',
          amount: totalDebtsPaid,
          percentage: (totalDebtsPaid / totalOutflow) * 100.0,
          colorValue: 0xFF2563EB, // Electric Blue
        ),
      );
    }
    if (totalReceivablesCollected > 0) {
      categoryBreakdown.add(
        MonthlyCategoryBreakdown(
          title: 'ได้รับเงินคืนแล้ว',
          amount: totalReceivablesCollected,
          percentage: (totalReceivablesCollected / totalOutflow) * 100.0,
          colorValue: 0xFF10B981, // Emerald Green
        ),
      );
    }
  }

  return MonthlyExpenseSummary(
    year: targetYear,
    month: targetMonth,
    totalOutflow: totalOutflow,
    totalInflow: totalInflow,
    totalCreatedBillsAmount: totalCreatedBills,
    totalDebtsPaidAmount: totalDebtsPaid,
    totalReceivablesCollected: totalReceivablesCollected,
    pendingReceivablesAmount: pendingReceivables,
    totalBillsCount: totalBillsCount,
    totalSettledCount: totalSettledCount,
    annualTrend: annualTrend,
    monthlyBills: monthlyBills,
    monthlyPaidDebts: monthlyPaidDebts,
    categoryBreakdown: categoryBreakdown,
  );
});
