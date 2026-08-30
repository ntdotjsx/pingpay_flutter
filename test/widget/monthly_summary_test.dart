import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingpay_mobile/features/analytics/presentation/monthly_summary_screen.dart';
import 'package:pingpay_mobile/features/analytics/providers/monthly_analytics_provider.dart';
import 'package:pingpay_mobile/features/bills/models/bill_models.dart';
import 'package:pingpay_mobile/features/bills/providers/bill_provider.dart';
import 'package:pingpay_mobile/features/payments/providers/payment_providers.dart';

class FakeUserDebtsNotifier extends StateNotifier<UserDebtsState> implements UserDebtsNotifier {
  FakeUserDebtsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('MonthlySummaryScreen renders header, bar chart, and metrics', (tester) async {
    final marchDate = DateTime(2026, 3, 10, 10, 0);
    final mockBill = BillModel(
      id: 'test-bill',
      ownerId: 'user-me',
      title: 'Buffet with team',
      totalAmount: 2500.0,
      status: 'unpaid',
      createdAt: marchDate,
      items: [
        BillItemParticipantModel(
          id: 'item-1',
          billId: 'test-bill',
          debtorId: 'user-friend-1',
          originalAmount: 500.0,
          currentAmount: 500.0,
          amountPaid: 500.0,
          amountWrittenOff: 0.0,
          status: 'paid',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedMonthlyPeriodProvider.overrideWith((ref) => DateTime(2026, 3, 1)),
          myBillsProvider.overrideWith((ref) => [mockBill]),
          userDebtsProvider.overrideWith(
            (ref) => FakeUserDebtsNotifier(
              const UserDebtsState(
                isLoading: false,
                allDebts: [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: MonthlySummaryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Month Header
    expect(find.text('สรุปค่าใช้จ่ายรายเดือน'), findsOneWidget);
    expect(find.text('มีนาคม 2569'), findsOneWidget);
    expect(find.text('แนวโน้มค่าใช้จ่ายทั้งปี'), findsOneWidget);
    expect(find.text('ออกเงินไปก่อน'), findsOneWidget);
    expect(find.text('Buffet with team'), findsOneWidget);

    // Tap on '📊 สรุปรายปี' Tab
    await tester.tap(find.text('📊 สรุปรายปี'));
    await tester.pumpAndSettle();

    // Verify Yearly Mode UI
    expect(find.text('สรุปค่าใช้จ่ายรายปี'), findsOneWidget);
    expect(find.text('ปี พ.ศ. 2569 (2026)'), findsOneWidget);
    expect(find.text('ยอดใช้จ่ายรวมตลอดทั้งปี'), findsOneWidget);
    expect(find.text('เฉลี่ยต่อเดือน'), findsOneWidget);
    expect(find.text('เดือนจ่ายสูงสุด'), findsOneWidget);
  });
}
