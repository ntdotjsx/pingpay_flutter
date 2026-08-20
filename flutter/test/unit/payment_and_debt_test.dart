import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/payments/models/payment_models.dart';
import 'package:pingpay_mobile/features/payments/services/debt_age_calculator.dart';

void main() {
  group('Payment & Debt Age Calculator Unit Tests', () {
    test('calculateDaysOutstanding: 0 days for today returns "ค้างวันนี้"', () {
      final now = DateTime(2026, 8, 20, 14, 30);
      final debtStart = DateTime(2026, 8, 20, 9, 0);

      final days = DebtAgeCalculator.calculateDaysOutstanding(
        debtStart,
        targetDate: now,
      );
      final text = DebtAgeCalculator.formatDebtAgeThai(
        debtStart,
        targetDate: now,
      );

      expect(days, equals(0));
      expect(text, equals('ค้างวันนี้'));
    });

    test(
      'calculateDaysOutstanding: 1 day for yesterday returns "ค้างมาแล้ว 1 วัน"',
      () {
        final now = DateTime(2026, 8, 20, 10, 0);
        final debtStart = DateTime(2026, 8, 19, 18, 0);

        final days = DebtAgeCalculator.calculateDaysOutstanding(
          debtStart,
          targetDate: now,
        );
        final text = DebtAgeCalculator.formatDebtAgeThai(
          debtStart,
          targetDate: now,
        );

        expect(days, equals(1));
        expect(text, equals('ค้างมาแล้ว 1 วัน'));
      },
    );

    test('calculateDaysOutstanding: 5 days returns "ค้างมาแล้ว 5 วัน"', () {
      final now = DateTime(2026, 8, 20);
      final debtStart = DateTime(2026, 8, 15);

      final days = DebtAgeCalculator.calculateDaysOutstanding(
        debtStart,
        targetDate: now,
      );
      final text = DebtAgeCalculator.formatDebtAgeThai(
        debtStart,
        targetDate: now,
      );

      expect(days, equals(5));
      expect(text, equals('ค้างมาแล้ว 5 วัน'));
    });

    test('calculateDaysOutstanding: 30 days returns "ค้างมาแล้ว 30 วัน"', () {
      final now = DateTime(2026, 8, 20);
      final debtStart = DateTime(2026, 7, 21);

      final days = DebtAgeCalculator.calculateDaysOutstanding(
        debtStart,
        targetDate: now,
      );
      final text = DebtAgeCalculator.formatDebtAgeThai(
        debtStart,
        targetDate: now,
      );

      expect(days, equals(30));
      expect(text, equals('ค้างมาแล้ว 30 วัน'));
    });

    test(
      'Timezone and hour boundary: 23:59 to 00:01 across midnight calculates 1 day',
      () {
        final debtStart = DateTime(2026, 8, 19, 23, 59);
        final now = DateTime(2026, 8, 20, 0, 1);

        final days = DebtAgeCalculator.calculateDaysOutstanding(
          debtStart,
          targetDate: now,
        );
        expect(days, equals(1));
      },
    );

    test('Thai date formatting matches Buddhist Era', () {
      final date = DateTime(2026, 8, 20);
      final formatted = DebtAgeCalculator.formatThaiDate(date);
      expect(formatted, equals('20 ส.ค. 2569'));
    });
  });

  group('Payment Models & Financial Invariant Tests', () {
    test(
      'DebtItemModel preserves financial invariant: current = paid + writtenOff + outstanding',
      () {
        final debt = DebtItemModel.fromJson({
          'id': 'item-1',
          'billId': 'bill-1',
          'debtorId': 'user-1',
          'billTitle': 'Dinner at ABC',
          'currency': 'THB',
          'originalAmount': 1000.0,
          'currentAmount': 1000.0,
          'amountPaid': 400.0,
          'amountWrittenOff': 0.0,
          'outstandingAmount': 600.0,
          'status': 'partially_paid',
          'isLocked': true,
          'isOutstanding': true,
          'debtStartDate': '2026-08-08T00:00:00Z',
          'creditor': {
            'id': 'owner-1',
            'userCode': 'USR-1234',
            'displayName': 'Somchai',
          },
        });

        expect(debt.creditor.displayName, equals('Somchai'));
        expect(debt.billTitle, equals('Dinner at ABC'));
        expect(debt.currentAmount, equals(1000.0));
        expect(debt.amountPaid, equals(400.0));
        expect(debt.outstandingAmount, equals(600.0));
        expect(debt.isPartiallyPaid, isTrue);
        expect(debt.paymentProgress, equals(0.4));
      },
    );

    test(
      'UserDebtsResponseModel parses summary counts and totals accurately',
      () {
        final response = UserDebtsResponseModel.fromJson({
          'summary': {
            'outstandingCount': 4,
            'totalOutstandingAmount': 2450.0,
            'currency': 'THB',
          },
          'debts': [
            {
              'id': 'item-1',
              'billId': 'bill-1',
              'debtorId': 'user-1',
              'billTitle': 'Dinner at ABC',
              'originalAmount': 500.0,
              'currentAmount': 500.0,
              'amountPaid': 0.0,
              'outstandingAmount': 500.0,
              'status': 'unpaid',
              'debtStartDate': '2026-08-08T00:00:00Z',
              'creditor': {
                'id': 'owner-1',
                'userCode': 'USR-1',
                'displayName': 'Somchai',
              },
            },
          ],
        });

        expect(response.summary.outstandingCount, equals(4));
        expect(response.summary.totalOutstandingAmount, equals(2450.0));
        expect(response.debts.length, equals(1));
      },
    );

    test(
      'PaymentInstallmentModel maintains separate installment records without overwriting',
      () {
        final installment1 = PaymentInstallmentModel.fromJson({
          'id': 'pay-1',
          'billItemId': 'item-1',
          'payerId': 'user-1',
          'amount': 200.0,
          'status': 'confirmed',
          'installmentNumber': 1,
          'createdAt': '2026-08-15T12:00:00Z',
        });

        final installment2 = PaymentInstallmentModel.fromJson({
          'id': 'pay-2',
          'billItemId': 'item-1',
          'payerId': 'user-1',
          'amount': 200.0,
          'status': 'confirmed',
          'installmentNumber': 2,
          'createdAt': '2026-08-18T14:30:00Z',
        });

        expect(installment1.id, isNot(equals(installment2.id)));
        expect(installment1.installmentNumber, equals(1));
        expect(installment2.installmentNumber, equals(2));
      },
    );

    test(
      'ReceivableSummaryModel parses unique debtor count and total correctly (e.g. Somchai with 2 bills counted as 1 debtor)',
      () {
        final response = UserReceivablesResponseModel.fromJson({
          'summary': {
            'debtorCount': 2,
            'totalOutstandingAmount': '1000.00',
            'totalPaidAmount': '400.00',
            'totalWrittenOffAmount': '0.00',
            'currency': 'THB',
          },
          'friends': [
            {
              'debtor': {
                'id': 'somchai-id',
                'userCode': 'SOM-001',
                'displayName': 'Somchai',
              },
              'outstandingBillCount': 2,
              'totalBillsCount': 2,
              'totalOriginalAmount': '800.00',
              'totalCurrentAmount': '800.00',
              'totalAmountPaid': '0.00',
              'totalAmountWrittenOff': '0.00',
              'totalOutstandingAmount': '800.00',
              'hasOutstandingDebt': true,
              'oldestDebtStartDate': '2026-08-01T00:00:00Z',
              'bills': [
                {
                  'id': 'item-1',
                  'billId': 'bill-1',
                  'billTitle': 'Dinner',
                  'originalAmount': '500.00',
                  'currentAmount': '500.00',
                  'amountPaid': '0.00',
                  'amountWrittenOff': '0.00',
                  'outstandingAmount': '500.00',
                  'status': 'unpaid',
                  'isLocked': false,
                  'isOutstanding': true,
                  'debtStartDate': '2026-08-01T00:00:00Z',
                },
                {
                  'id': 'item-2',
                  'billId': 'bill-2',
                  'billTitle': 'Trip',
                  'originalAmount': '300.00',
                  'currentAmount': '300.00',
                  'amountPaid': '0.00',
                  'amountWrittenOff': '0.00',
                  'outstandingAmount': '300.00',
                  'status': 'unpaid',
                  'isLocked': false,
                  'isOutstanding': true,
                  'debtStartDate': '2026-08-05T00:00:00Z',
                },
              ],
            },
            {
              'debtor': {
                'id': 'jane-id',
                'userCode': 'JAN-002',
                'displayName': 'Jane',
              },
              'outstandingBillCount': 1,
              'totalBillsCount': 1,
              'totalOriginalAmount': '200.00',
              'totalCurrentAmount': '200.00',
              'totalAmountPaid': '0.00',
              'totalAmountWrittenOff': '0.00',
              'totalOutstandingAmount': '200.00',
              'hasOutstandingDebt': true,
              'oldestDebtStartDate': '2026-08-10T00:00:00Z',
              'bills': [
                {
                  'id': 'item-3',
                  'billId': 'bill-3',
                  'billTitle': 'Coffee',
                  'originalAmount': '200.00',
                  'currentAmount': '200.00',
                  'amountPaid': '0.00',
                  'amountWrittenOff': '0.00',
                  'outstandingAmount': '200.00',
                  'status': 'unpaid',
                  'isLocked': false,
                  'isOutstanding': true,
                  'debtStartDate': '2026-08-10T00:00:00Z',
                },
              ],
            },
          ],
        });

        expect(response.summary.debtorCount, equals(2));
        expect(response.summary.totalOutstandingAmount, equals(1000.0));
        expect(response.friends.length, equals(2));
        expect(response.friends[0].debtor.displayName, equals('Somchai'));
        expect(response.friends[0].outstandingBillCount, equals(2));
        expect(response.friends[0].totalOutstandingAmount, equals(800.0));
        expect(response.friends[1].debtor.displayName, equals('Jane'));
        expect(response.friends[1].totalOutstandingAmount, equals(200.0));
      },
    );

    test(
      'Receivable partial payment and write-off arithmetic: original 1000, paid 200, written off 300 = outstanding 500',
      () {
        final item = ReceivableBillItemModel.fromJson({
          'id': 'item-writeoff-1',
          'billId': 'bill-1',
          'billTitle': 'Large Trip',
          'originalAmount': '1000.00',
          'currentAmount': '1000.00',
          'amountPaid': '200.00',
          'amountWrittenOff': '300.00',
          'outstandingAmount': '500.00',
          'status': 'partially_paid',
          'isLocked': true,
          'isOutstanding': true,
          'debtStartDate': '2026-08-01T00:00:00Z',
        });

        expect(item.originalAmount, equals(1000.0));
        expect(item.amountPaid, equals(200.0));
        expect(item.amountWrittenOff, equals(300.0));
        expect(item.outstandingAmount, equals(500.0));
        expect(item.hasRemainingDebt, isTrue);
        expect(item.isPartiallyPaid, isTrue);
      },
    );
  });
}
