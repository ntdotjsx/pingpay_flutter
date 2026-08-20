import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/core/theme/light_theme.dart';
import 'package:pingpay_mobile/features/payments/models/payment_models.dart';
import 'package:pingpay_mobile/features/payments/presentation/widgets/debt_card.dart';
import 'package:pingpay_mobile/features/payments/presentation/widgets/payment_summary_card.dart';
import 'package:pingpay_mobile/features/payments/presentation/widgets/receivable_friend_card.dart';
import 'package:pingpay_mobile/features/payments/presentation/widgets/receivable_summary_card.dart';

void main() {
  testWidgets('PaymentSummaryCard renders count and total amount correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LightTheme.theme,
        home: const Scaffold(
          body: PaymentSummaryCard(
            outstandingCount: 4,
            totalOutstandingAmount: 2450.0,
          ),
        ),
      ),
    );

    expect(find.text('ค้างชำระ'), findsOneWidget);
    expect(find.text('4 รายการ'), findsOneWidget);
    expect(find.text('฿2450.00'), findsOneWidget);
    expect(find.text('ยอดที่ต้องชำระทั้งหมด'), findsOneWidget);
  });

  testWidgets(
    'DebtCard renders creditor name, bill title, outstanding amount and pay button when acknowledged',
    (tester) async {
      final debt = DebtItemModel(
        id: 'debt-1',
        billId: 'bill-1',
        debtorId: 'debtor-1',
        billTitle: 'Dinner at ABC',
        originalAmount: 1000.0,
        currentAmount: 1000.0,
        amountPaid: 400.0,
        outstandingAmount: 600.0,
        status: 'partially_paid',
        isAcknowledged: true,
        debtStartDate: DateTime.now().subtract(const Duration(days: 12)),
        creditor: const CreditorUserModel(
          id: 'owner-1',
          userCode: 'USR-100',
          displayName: 'Somchai',
        ),
      );

      bool payTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: LightTheme.theme,
          home: Scaffold(
            body: DebtCard(
              debt: debt,
              onPayTap: () {
                payTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Somchai'), findsOneWidget);
      expect(find.text('Dinner at ABC'), findsOneWidget);
      expect(find.text('ค้าง ฿600.00'), findsOneWidget);
      expect(find.text('ชำระแล้ว ฿400.00'), findsOneWidget);
      expect(find.text('ค้างมาแล้ว 12 วัน'), findsOneWidget);
      expect(find.text('จ่ายเงิน'), findsOneWidget);

      await tester.tap(find.text('จ่ายเงิน'));
      expect(payTapped, isTrue);
    },
  );

  testWidgets(
    'ReceivableSummaryCard renders debtor count and total receivable correctly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LightTheme.theme,
          home: const Scaffold(
            body: ReceivableSummaryCard(
              debtorCount: 3,
              totalOutstandingAmount: 1850.0,
            ),
          ),
        ),
      );

      expect(find.text('เพื่อนติดเรา'), findsOneWidget);
      expect(find.text('3 คน'), findsOneWidget);
      expect(find.text('1850.00'), findsOneWidget);
      expect(
        find.text('ยอดที่ยังไม่ได้รับ (เพื่อนยังค้างชำระ)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ReceivableFriendCard renders friend name, outstanding bills count and "ติดเรา" label',
    (tester) async {
      final friend = ReceivableFriendModel(
        debtor: const DebtorUserModel(
          id: 'user-somchai',
          userCode: 'SOM-001',
          displayName: 'Somchai',
        ),
        outstandingBillCount: 3,
        totalBillsCount: 3,
        totalOriginalAmount: 1500.0,
        totalCurrentAmount: 1500.0,
        totalAmountPaid: 250.0,
        totalAmountWrittenOff: 0.0,
        totalOutstandingAmount: 1250.0,
        hasOutstandingDebt: true,
        oldestDebtStartDate: DateTime.now().subtract(const Duration(days: 18)),
        bills: [],
      );

      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: LightTheme.theme,
          home: Scaffold(
            body: ReceivableFriendCard(
              friend: friend,
              onTap: () {
                cardTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Somchai'), findsOneWidget);
      expect(find.text('3 รายการค้างชำระ'), findsOneWidget);
      expect(find.text('ติดเรา'), findsOneWidget);
      expect(find.text('฿1250.00'), findsOneWidget);
      expect(find.text('จ่ายแล้ว'), findsOneWidget);
      expect(find.text('฿250.00'), findsOneWidget);
      expect(find.text('ดูรายละเอียด'), findsOneWidget);

      await tester.tap(find.text('ดูรายละเอียด'));
      expect(cardTapped, isTrue);
    },
  );
}
