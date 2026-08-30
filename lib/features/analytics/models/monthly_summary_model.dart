import '../../bills/models/bill_models.dart';

/// Represents aggregated financial statistics for a specific month
class MonthlyExpenseSummary {
  final int year;
  final int month;
  final double totalOutflow; // Bills paid/created + Debts paid to friends
  final double totalInflow; // Money collected/received from friends
  final double totalCreatedBillsAmount; // Total amount of bills created by user
  final double totalDebtsPaidAmount; // Total debt payments made by user
  final double totalReceivablesCollected; // Total money collected from debtors
  final double pendingReceivablesAmount; // Amount friends still owe for bills this month
  final int totalBillsCount;
  final int totalSettledCount;
  final List<MonthlyDataPoint> annualTrend; // 12 months trend data for the year
  final List<BillModel> monthlyBills; // Bills created in this month
  final List<MonthlyCategoryBreakdown> categoryBreakdown;

  const MonthlyExpenseSummary({
    required this.year,
    required this.month,
    required this.totalOutflow,
    required this.totalInflow,
    required this.totalCreatedBillsAmount,
    required this.totalDebtsPaidAmount,
    required this.totalReceivablesCollected,
    required this.pendingReceivablesAmount,
    required this.totalBillsCount,
    required this.totalSettledCount,
    required this.annualTrend,
    required this.monthlyBills,
    required this.categoryBreakdown,
  });

  double get settlementRate {
    if (totalBillsCount == 0) return 100.0;
    return (totalSettledCount / totalBillsCount) * 100.0;
  }

  factory MonthlyExpenseSummary.empty(int year, int month) {
    return MonthlyExpenseSummary(
      year: year,
      month: month,
      totalOutflow: 0.0,
      totalInflow: 0.0,
      totalCreatedBillsAmount: 0.0,
      totalDebtsPaidAmount: 0.0,
      totalReceivablesCollected: 0.0,
      pendingReceivablesAmount: 0.0,
      totalBillsCount: 0,
      totalSettledCount: 0,
      annualTrend: List.generate(
        12,
        (i) => MonthlyDataPoint(
          month: i + 1,
          monthName: _monthNames[i],
          outflow: 0.0,
          inflow: 0.0,
        ),
      ),
      monthlyBills: const [],
      categoryBreakdown: const [],
    );
  }

  static const List<String> _monthNames = [
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
}

/// Represents a single month data point in the annual bar chart
class MonthlyDataPoint {
  final int month;
  final String monthName;
  final double outflow;
  final double inflow;

  const MonthlyDataPoint({
    required this.month,
    required this.monthName,
    required this.outflow,
    required this.inflow,
  });
}

/// Category/Type breakdown item (e.g. อาหาร, ปาร์ตี้, ท่องเที่ยว, ทั่วไป)
class MonthlyCategoryBreakdown {
  final String title;
  final double amount;
  final double percentage;
  final int colorValue;

  const MonthlyCategoryBreakdown({
    required this.title,
    required this.amount,
    required this.percentage,
    required this.colorValue,
  });
}
