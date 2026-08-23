import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/bills/models/bill_models.dart';
import 'package:pingpay_mobile/features/bills/services/bill_split_calculator.dart';

void main() {
  group('BillSplitCalculator & Model Calculation Invariants', () {
    test('Case 1: Total = 498, 2 participants (1 creator + 1 debtor)', () {
      final totalSatang = BillSplitCalculator.toSatang(498.0);
      expect(totalSatang, 49800);

      final participants = [
        const BillSplitParticipant(
          userId: 'debtor-1',
          displayName: 'Debtor A',
          userCode: 'USR-A',
          amountSatang: 0,
        ),
      ];

      // Creator is included in the split
      final splitResult = BillSplitCalculator.calculateSplitWithOptions(
        participants: participants,
        totalSatang: totalSatang,
        includeOwner: true,
      );

      final ownerSatang = splitResult.ownerSatang;
      final debtorSatang = splitResult.participants[0].amountSatang;

      expect(ownerSatang, 24900); // 249.00 THB
      expect(debtorSatang, 24900); // 249.00 THB
      expect(BillSplitCalculator.toBaht(ownerSatang), 249.0);
      expect(BillSplitCalculator.toBaht(debtorSatang), 249.0);

      // Verify invariant: totalSatang == ownerSatang + debtorSatang
      expect(
        BillSplitCalculator.validateTotalInvariant(
          splitResult.participants,
          totalSatang,
          ownerSatang: ownerSatang,
        ),
        isTrue,
      );

      // Construct BillModel to verify derived getters
      final bill = BillModel(
        id: 'bill-1',
        ownerId: 'owner-1',
        title: 'Dinner 498',
        totalAmount: 498.0,
        status: 'unpaid',
        items: [
          const BillItemParticipantModel(
            id: 'item-1',
            billId: 'bill-1',
            debtorId: 'debtor-1',
            originalAmount: 249.0,
            currentAmount: 249.0,
            amountPaid: 0.0,
            amountWrittenOff: 0.0,
            status: 'unpaid',
          ),
        ],
      );

      expect(bill.totalAmount, 498.0); // Total paid upfront
      expect(bill.myShare, 249.0); // Creator own share
      expect(bill.totalDebtorsAmount, 249.0); // Total debtor debt
      expect(bill.totalOutstandingAmount, 249.0); // Total outstanding to collect
      expect(bill.totalOutstandingAmount, isNot(498.0)); // MUST NOT be 498!
    });

    test('Case 2: Total = 498, 3 participants (1 creator + 2 debtors)', () {
      final totalSatang = BillSplitCalculator.toSatang(498.0);
      expect(totalSatang, 49800);

      final participants = [
        const BillSplitParticipant(
          userId: 'debtor-1',
          displayName: 'Debtor A',
          userCode: 'USR-A',
          amountSatang: 0,
        ),
        const BillSplitParticipant(
          userId: 'debtor-2',
          displayName: 'Debtor B',
          userCode: 'USR-B',
          amountSatang: 0,
        ),
      ];

      // Creator is included in the split (3 shares total)
      final splitResult = BillSplitCalculator.calculateSplitWithOptions(
        participants: participants,
        totalSatang: totalSatang,
        includeOwner: true,
      );

      final ownerSatang = splitResult.ownerSatang;
      final debtor1Satang = splitResult.participants[0].amountSatang;
      final debtor2Satang = splitResult.participants[1].amountSatang;

      expect(ownerSatang, 16600); // 166.00 THB
      expect(debtor1Satang, 16600); // 166.00 THB
      expect(debtor2Satang, 16600); // 166.00 THB

      // Verify invariant: totalSatang == ownerSatang + debtor1Satang + debtor2Satang
      expect(
        BillSplitCalculator.validateTotalInvariant(
          splitResult.participants,
          totalSatang,
          ownerSatang: ownerSatang,
        ),
        isTrue,
      );

      // Construct BillModel
      final bill = BillModel(
        id: 'bill-2',
        ownerId: 'owner-1',
        title: 'Shabu 498',
        totalAmount: 498.0,
        status: 'unpaid',
        items: [
          const BillItemParticipantModel(
            id: 'item-1',
            billId: 'bill-2',
            debtorId: 'debtor-1',
            originalAmount: 166.0,
            currentAmount: 166.0,
            amountPaid: 0.0,
            amountWrittenOff: 0.0,
            status: 'unpaid',
          ),
          const BillItemParticipantModel(
            id: 'item-2',
            billId: 'bill-2',
            debtorId: 'debtor-2',
            originalAmount: 166.0,
            currentAmount: 166.0,
            amountPaid: 0.0,
            amountWrittenOff: 0.0,
            status: 'unpaid',
          ),
        ],
      );

      expect(bill.totalAmount, 498.0); // Total paid upfront by creator
      expect(bill.myShare, 166.0); // Creator own share
      expect(bill.totalDebtorsAmount, 332.0); // Total debtor debt (166 + 166)
      expect(bill.totalOutstandingAmount, 332.0); // Money owed to creator
      expect(bill.totalOutstandingAmount, isNot(498.0)); // MUST NOT be 498!
    });

    test('Payment status and partial payments only affect outstanding, never total debt share', () {
      final item = const BillItemParticipantModel(
        id: 'item-1',
        billId: 'bill-1',
        debtorId: 'debtor-1',
        originalAmount: 249.0,
        currentAmount: 249.0,
        amountPaid: 100.0,
        amountWrittenOff: 0.0,
        status: 'partially_paid',
      );

      expect(item.currentAmount, 249.0); // Debt share remains 249.0
      expect(item.amountPaid, 100.0);
      expect(item.outstandingAmount, 149.0); // 249 - 100 = 149.0

      // When fully paid
      final paidItem = const BillItemParticipantModel(
        id: 'item-1',
        billId: 'bill-1',
        debtorId: 'debtor-1',
        originalAmount: 249.0,
        currentAmount: 249.0,
        amountPaid: 249.0,
        amountWrittenOff: 0.0,
        status: 'paid',
      );

      expect(paidItem.currentAmount, 249.0); // Original and current debt share still 249.0
      expect(paidItem.outstandingAmount, 0.0); // Outstanding is 0
      expect(paidItem.isFullyPaid, isTrue);
    });

    test('Excluding creator from split allocates entire bill to friends only', () {
      final totalSatang = BillSplitCalculator.toSatang(498.0);
      final participants = [
        const BillSplitParticipant(
          userId: 'debtor-1',
          displayName: 'Debtor A',
          userCode: 'USR-A',
          amountSatang: 0,
        ),
        const BillSplitParticipant(
          userId: 'debtor-2',
          displayName: 'Debtor B',
          userCode: 'USR-B',
          amountSatang: 0,
        ),
      ];

      final splitResult = BillSplitCalculator.calculateSplitWithOptions(
        participants: participants,
        totalSatang: totalSatang,
        includeOwner: false,
      );

      expect(splitResult.ownerSatang, 0);
      expect(splitResult.participants[0].amountSatang, 24900);
      expect(splitResult.participants[1].amountSatang, 24900);
    });
  });
}
