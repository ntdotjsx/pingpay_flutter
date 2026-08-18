import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/bills/models/bill_models.dart';
import 'package:pingpay_mobile/features/bills/models/ocr_models.dart';
import 'package:pingpay_mobile/features/bills/services/bill_split_calculator.dart';

void main() {
  group('Feature 3: Financial Calculations & Deterministic Arithmetic', () {
    test('allocateEvenlySatang handles exact division with zero remainder', () {
      // 1000 THB = 100000 satang / 2 = 50000 satang each (500.00 THB)
      final res = BillSplitCalculator.allocateEvenlySatang(100000, 2);
      expect(res, [50000, 50000]);
      expect(res.reduce((a, b) => a + b), 100000);
    });

    test(
      'allocateEvenlySatang deterministically distributes 100 THB / 3 people',
      () {
        // 100 THB = 10000 satang / 3 = 3333 satang base + 1 remainder
        // Result: [3334, 3333, 3333] satang (33.34, 33.33, 33.33 THB)
        final res = BillSplitCalculator.allocateEvenlySatang(10000, 3);
        expect(res, [3334, 3333, 3333]);
        expect(res.reduce((a, b) => a + b), 10000);
      },
    );

    test(
      'calculateSplitWithOptions includes owner and reduces friends share',
      () {
        final initial = [
          const BillSplitParticipant(
            userId: 'u1',
            displayName: 'Somchai',
            userCode: '1',
            amountSatang: 0,
          ),
        ];

        // Total 232.00 THB = 23200 satang. With owner included: 23200 / 2 = 11600 satang (116.00 THB each)
        final split = BillSplitCalculator.calculateSplitWithOptions(
          participants: initial,
          totalSatang: 23200,
          includeOwner: true,
        );

        expect(split.ownerSatang, 11600);
        expect(split.participants[0].amountSatang, 11600);
        expect(
          BillSplitCalculator.validateTotalInvariant(
            split.participants,
            23200,
            ownerSatang: split.ownerSatang,
          ),
          isTrue,
        );
      },
    );

    test('calculateSplitWithOptions allows custom owner deduction amount', () {
      final initial = [
        const BillSplitParticipant(
          userId: 'u1',
          displayName: 'Somchai',
          userCode: '1',
          amountSatang: 0,
        ),
        const BillSplitParticipant(
          userId: 'u2',
          displayName: 'Jane',
          userCode: '2',
          amountSatang: 0,
        ),
      ];

      // Total 1000.00 THB = 100000 satang. Owner pays 400.00 THB (40000 satang).
      // Remaining 60000 satang / 2 friends = 30000 satang (300.00 THB each).
      final split = BillSplitCalculator.calculateSplitWithOptions(
        participants: initial,
        totalSatang: 100000,
        includeOwner: true,
        customOwnerSatang: 40000,
      );

      expect(split.ownerSatang, 40000);
      expect(split.participants[0].amountSatang, 30000);
      expect(split.participants[1].amountSatang, 30000);
      expect(
        BillSplitCalculator.validateTotalInvariant(
          split.participants,
          100000,
          ownerSatang: split.ownerSatang,
        ),
        isTrue,
      );
    });

    test(
      'adjustParticipantAmount maintains SUM == Total invariant when first person changes',
      () {
        final initial = [
          const BillSplitParticipant(
            userId: 'u1',
            displayName: 'A',
            userCode: '1',
            amountSatang: 33334,
          ),
          const BillSplitParticipant(
            userId: 'u2',
            displayName: 'B',
            userCode: '2',
            amountSatang: 33333,
          ),
          const BillSplitParticipant(
            userId: 'u3',
            displayName: 'C',
            userCode: '3',
            amountSatang: 33333,
          ),
        ];

        // Total = 1000.00 THB = 100000 satang
        // User changes A -> 500.00 THB (50000 satang)
        // Remaining = 50000 satang / 2 = 25000 satang each (250.00 THB)
        final adjusted = BillSplitCalculator.adjustParticipantAmount(
          participants: initial,
          totalSatang: 100000,
          targetIndex: 0,
          newAmountSatang: 50000,
        );

        expect(adjusted[0].amountSatang, 50000);
        expect(adjusted[1].amountSatang, 25000);
        expect(adjusted[2].amountSatang, 25000);
        expect(
          BillSplitCalculator.validateTotalInvariant(adjusted, 100000),
          isTrue,
        );
      },
    );

    test(
      'adjustParticipantAmount clamps amounts between 0 and totalSatang',
      () {
        final initial = [
          const BillSplitParticipant(
            userId: 'u1',
            displayName: 'A',
            userCode: '1',
            amountSatang: 50000,
          ),
          const BillSplitParticipant(
            userId: 'u2',
            displayName: 'B',
            userCode: '2',
            amountSatang: 50000,
          ),
        ];

        // Attempt setting amount higher than total
        final adjusted = BillSplitCalculator.adjustParticipantAmount(
          participants: initial,
          totalSatang: 100000,
          targetIndex: 0,
          newAmountSatang: 150000,
        );

        expect(adjusted[0].amountSatang, 100000);
        expect(adjusted[1].amountSatang, 0);
        expect(
          BillSplitCalculator.validateTotalInvariant(adjusted, 100000),
          isTrue,
        );
      },
    );
  });

  group('Feature 3: Bill & OCR Models Serialization & Accounting Tests', () {
    test(
      'ReceiptOcrResultModel filters out summary and total lines from items',
      () {
        final json = {
          'merchant': 'ร้านอาหารแซ่บ',
          'totalAmount': 228.0,
          'items': [
            {'name': 'ยำยอดมะขาม', 'amount': 62.0, 'quantity': 1},
            {'name': 'ข้าวสวย', 'amount': 15.0, 'quantity': 1},
            {'name': 'น้ำดื่ม', 'amount': 12.0, 'quantity': 1},
            {'name': 'ทงเ หคัดจำนวเนจิง', 'amount': 228.0, 'quantity': 1},
            {'name': 'ยอดรวมทั้งสิ้น', 'amount': 228.0, 'quantity': 1},
          ],
        };

        final model = ReceiptOcrResultModel.fromJson(json);
        expect(model.items.length, 3);
        expect(model.items.map((i) => i.name), [
          'ยำยอดมะขาม',
          'ข้าวสวย',
          'น้ำดื่ม',
        ]);
      },
    );

    test(
      'BillItemParticipantModel maintains separate Paid vs Written Off amounts',
      () {
        const p = BillItemParticipantModel(
          id: 'p1',
          billId: 'b1',
          debtorId: 'u1',
          originalAmount: 500.0,
          currentAmount: 500.0,
          status: 'partially_paid',
          amountPaid: 200.0,
          amountWrittenOff: 100.0,
        );

        // Remaining balance = 500 - 200 - 100 = 200
        expect(p.outstandingAmount, 200.0);
        expect(p.isFullyPaid, isFalse);
      },
    );

    test('BillModel correctly computes totals across participants', () {
      final bill = BillModel(
        id: 'b1',
        title: 'Shabu Dinner',
        totalAmount: 1200.0,
        ownerId: 'u0',
        status: 'unpaid',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        items: const [
          BillItemParticipantModel(
            id: 'p1',
            billId: 'b1',
            debtorId: 'u1',
            originalAmount: 600.0,
            currentAmount: 600.0,
            status: 'paid',
            amountPaid: 600.0,
          ),
          BillItemParticipantModel(
            id: 'p2',
            billId: 'b1',
            debtorId: 'u2',
            originalAmount: 600.0,
            currentAmount: 600.0,
            status: 'unpaid',
            amountPaid: 0.0,
          ),
        ],
      );

      expect(bill.totalPaidAmount, 600.0);
      expect(bill.totalOutstandingAmount, 600.0);
    });
  });
}
