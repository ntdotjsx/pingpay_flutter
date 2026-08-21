import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pingpay_mobile/features/home/presentation/widgets/line_calendar_widget.dart';
import 'package:pingpay_mobile/features/home/presentation/widgets/daily_timeline_section.dart';
import 'package:pingpay_mobile/features/bills/models/bill_models.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th', null);
  });

  group('LineCalendarWidget & DailyTimelineSection Tests', () {
    testWidgets('LineCalendarWidget renders and triggers date selection', (
      tester,
    ) async {
      final today = DateTime.now();
      final selectedDate = DateTime(today.year, today.month, today.day);
      DateTime? tappedDate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LineCalendarWidget(
                selectedDate: selectedDate,
                onDateSelected: (d) => tappedDate = d,
                activeEventDates: {
                  DateFormat('yyyy-MM-dd').format(selectedDate),
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LineCalendarWidget), findsOneWidget);
      expect(find.text(selectedDate.day.toString()), findsWidgets);

      await tester.tap(find.text(selectedDate.day.toString()).first);
      await tester.pumpAndSettle();
      expect(tappedDate, isNotNull);
    });

    testWidgets('DailyTimelineSection shows empty state when no bills', (
      tester,
    ) async {
      final today = DateTime.now();
      bool createBillCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyTimelineSection(
                selectedDate: today,
                bills: const [],
                onCreateBill: () => createBillCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ไม่มีรายการบิลในวันนี้'), findsOneWidget);
      expect(find.text('สร้างบิลใหม่'), findsOneWidget);

      await tester.tap(find.text('สร้างบิลใหม่'));
      await tester.pumpAndSettle();

      expect(createBillCalled, isTrue);
    });

    testWidgets('DailyTimelineSection shows bills and summary metrics', (
      tester,
    ) async {
      final today = DateTime.now();
      final mockBill = BillModel(
        id: 'bill-123',
        ownerId: 'user-1',
        title: 'มื้อเที่ยงส้มตำ',
        totalAmount: 600.0,
        status: 'unpaid',
        createdAt: today,
        items: [
          const BillItemParticipantModel(
            id: 'item-1',
            billId: 'bill-123',
            debtorId: 'debtor-1',
            originalAmount: 300.0,
            currentAmount: 300.0,
            amountPaid: 100.0,
            status: 'partially_paid',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyTimelineSection(
                selectedDate: today,
                bills: [mockBill],
                onCreateBill: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('มื้อเที่ยงส้มตำ'), findsOneWidget);
      expect(find.text('฿600.00'), findsOneWidget);
      expect(find.text('ยอดรวมบิล'), findsOneWidget);
      expect(find.text('฿600'), findsOneWidget);
    });
  });
}
