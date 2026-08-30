import '../../bills/models/bill_models.dart';
import 'monthly_summary_model.dart';

/// Represents aggregated financial statistics for an entire year
class YearlyExpenseSummary {
  final int year;
  final double totalOutflow; // Total bills created + total debts paid for the whole year
  final double totalInflow; // Total receivables collected from friends for the whole year
  final double totalCreatedBillsAmount;
  final double totalDebtsPaidAmount;
  final double totalReceivablesCollected;
  final double pendingReceivablesAmount;
  final int totalBillsCount;
  final int totalSettledCount;
  final double averageMonthlyExpense;
  final MonthlyDataPoint? peakSpendingMonth;
  final List<MonthlyDataPoint> monthlyTrend; // 12 months data
  final List<BillModel> yearlyBills; // All bills created in this year
  final List<MonthlyCategoryBreakdown> categoryBreakdown;

  const YearlyExpenseSummary({
    required this.year,
    required this.totalOutflow,
    required this.totalInflow,
    required this.totalCreatedBillsAmount,
    required this.totalDebtsPaidAmount,
    required this.totalReceivablesCollected,
    required this.pendingReceivablesAmount,
    required this.totalBillsCount,
    required this.totalSettledCount,
    required this.averageMonthlyExpense,
    this.peakSpendingMonth,
    required this.monthlyTrend,
    required this.yearlyBills,
    required this.categoryBreakdown,
  });

  double get settlementRate {
    if (totalBillsCount == 0) return 100.0;
    return (totalSettledCount / totalBillsCount) * 100.0;
  }

  factory YearlyExpenseSummary.empty(int year) {
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

    return YearlyExpenseSummary(
      year: year,
      totalOutflow: 0.0,
      totalInflow: 0.0,
      totalCreatedBillsAmount: 0.0,
      totalDebtsPaidAmount: 0.0,
      totalReceivablesCollected: 0.0,
      pendingReceivablesAmount: 0.0,
      totalBillsCount: 0,
      totalSettledCount: 0,
      averageMonthlyExpense: 0.0,
      peakSpendingMonth: null,
      monthlyTrend: List.generate(
        12,
        (i) => MonthlyDataPoint(
          month: i + 1,
          monthName: monthNames[i],
          outflow: 0.0,
          inflow: 0.0,
        ),
      ),
      yearlyBills: const [],
      categoryBreakdown: const [],
    );
  }
}
