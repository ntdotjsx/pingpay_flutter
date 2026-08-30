import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingpay_mobile/features/analytics/models/monthly_summary_model.dart';
import 'package:pingpay_mobile/features/analytics/providers/monthly_analytics_provider.dart';
import 'package:pingpay_mobile/features/analytics/providers/yearly_analytics_provider.dart';
import 'package:pingpay_mobile/features/bills/models/bill_models.dart';
import 'package:pingpay_mobile/features/bills/providers/bill_provider.dart';
import 'package:pingpay_mobile/features/payments/models/payment_models.dart';
import 'package:pingpay_mobile/features/payments/providers/payment_providers.dart';

class FakeUserDebtsNotifier extends StateNotifier<UserDebtsState> implements UserDebtsNotifier {
  FakeUserDebtsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Monthly Analytics & Expense Summary Tests', () {
    test('MonthlyExpenseSummary.empty initializes 12 months with 0.0 amounts', () {
      final emptySummary = MonthlyExpenseSummary.empty(2026, 3);
      expect(emptySummary.year, 2026);
      expect(emptySummary.month, 3);
      expect(emptySummary.totalOutflow, 0.0);
      expect(emptySummary.totalInflow, 0.0);
      expect(emptySummary.totalBillsCount, 0);
      expect(emptySummary.annualTrend.length, 12);
      expect(emptySummary.annualTrend[0].monthName, 'ม.ค.');
      expect(emptySummary.annualTrend[11].monthName, 'ธ.ค.');
      expect(emptySummary.settlementRate, 100.0);
    });

    test('monthlyAnalyticsProvider aggregates monthly bills and debts accurately', () {
      final testDateMarch = DateTime(2026, 3, 15, 12, 0);
      final testDateApril = DateTime(2026, 4, 10, 14, 0);

      final bill1March = BillModel(
        id: 'bill-1',
        ownerId: 'user-me',
        title: 'Shabu with friends',
        totalAmount: 1200.0,
        status: 'unpaid',
        createdAt: testDateMarch,
        items: [
          BillItemParticipantModel(
            id: 'item-1',
            billId: 'bill-1',
            debtorId: 'user-friend-1',
            originalAmount: 400.0,
            currentAmount: 400.0,
            amountPaid: 200.0, // partially paid
            amountWrittenOff: 0.0,
            status: 'partially_paid',
          ),
          BillItemParticipantModel(
            id: 'item-2',
            billId: 'bill-1',
            debtorId: 'user-friend-2',
            originalAmount: 400.0,
            currentAmount: 400.0,
            amountPaid: 400.0, // fully paid
            amountWrittenOff: 0.0,
            status: 'paid',
          ),
        ],
      );

      final bill2April = BillModel(
        id: 'bill-2',
        ownerId: 'user-me',
        title: 'April BBQ',
        totalAmount: 800.0,
        status: 'paid',
        createdAt: testDateApril,
        items: [],
      );

      // Cancelled bill - should be ignored
      final billCancelled = BillModel(
        id: 'bill-cancelled',
        ownerId: 'user-me',
        title: 'Cancelled Dinner',
        totalAmount: 5000.0,
        status: 'cancelled',
        createdAt: testDateMarch,
        items: [],
      );

      // Written-off bill - should be ignored from total outflow
      final billWrittenOff = BillModel(
        id: 'bill-written-off',
        ownerId: 'user-me',
        title: 'Written off',
        totalAmount: 1000.0,
        status: 'fully_written_off',
        createdAt: testDateMarch,
        items: [],
      );

      final debtMarch = DebtItemModel(
        id: 'debt-1',
        billId: 'bill-other',
        debtorId: 'debtor-me',
        billTitle: 'Movie Ticket',
        originalAmount: 300.0,
        currentAmount: 300.0,
        amountPaid: 300.0,
        amountWrittenOff: 0.0,
        outstandingAmount: 0.0,
        status: 'paid',
        debtStartDate: testDateMarch,
        creditor: const CreditorUserModel(
          id: 'user-other',
          userCode: 'USR-001',
          displayName: 'Friend A',
          promptPayId: '0812345678',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          selectedMonthlyPeriodProvider.overrideWith((ref) => DateTime(2026, 3, 1)),
          myBillsProvider.overrideWith(
            (ref) => [bill1March, bill2April, billCancelled, billWrittenOff],
          ),
          userDebtsProvider.overrideWith(
            (ref) => FakeUserDebtsNotifier(
              UserDebtsState(
                isLoading: false,
                allDebts: [debtMarch],
              ),
            ),
          ),
        ],
      );

      final summary = container.read(monthlyAnalyticsProvider);

      expect(summary.year, 2026);
      expect(summary.month, 3);
      expect(summary.totalCreatedBillsAmount, 1200.0);
      expect(summary.totalDebtsPaidAmount, 300.0);
      expect(summary.totalOutflow, 1500.0); // 1200 + 300
      expect(summary.totalReceivablesCollected, 600.0); // 200 + 400
      expect(summary.totalInflow, 600.0);
      expect(summary.pendingReceivablesAmount, 200.0); // 400 - 200
      expect(summary.totalBillsCount, 1); // Only bill1March (excludes cancelled and written off)
      expect(summary.monthlyBills.length, 1);
      expect(summary.monthlyBills.first.id, 'bill-1');

      // Check annual trend (March index is 2)
      expect(summary.annualTrend[2].outflow, 1500.0);
      expect(summary.annualTrend[2].inflow, 600.0);
      expect(summary.annualTrend[3].outflow, 800.0); // April bill

      // Check yearly summary provider
      container.read(selectedYearProvider.notifier).state = 2026;
      final yearlySummary = container.read(yearlyAnalyticsProvider);

      expect(yearlySummary.year, 2026);
      expect(yearlySummary.totalCreatedBillsAmount, 2000.0); // 1200 + 800
      expect(yearlySummary.totalDebtsPaidAmount, 300.0);
      expect(yearlySummary.totalOutflow, 2300.0); // 2000 + 300
      expect(yearlySummary.totalBillsCount, 2); // 2 active bills in 2026
      expect(yearlySummary.yearlyBills.length, 2);
      expect(yearlySummary.averageMonthlyExpense, 2300.0 / 12.0);
      expect(yearlySummary.peakSpendingMonth?.month, 3); // March has 1500 vs April 800
      expect(yearlySummary.peakSpendingMonth?.outflow, 1500.0);
    });
  });
}
