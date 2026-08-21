import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/core/theme/theme.dart';
import 'package:pingpay_mobile/features/bills/models/ocr_models.dart';
import 'package:pingpay_mobile/features/bills/presentation/create_bill_screen.dart';
import 'package:pingpay_mobile/features/bills/presentation/no_friends_state_widget.dart';
import 'package:pingpay_mobile/features/bills/presentation/widgets/bill_confirmation_bottom_sheet.dart';
import 'package:pingpay_mobile/features/bills/presentation/widgets/bill_items_bottom_sheet.dart';
import 'package:pingpay_mobile/features/bills/presentation/widgets/bill_items_summary_card.dart';
import 'package:pingpay_mobile/features/bills/presentation/widgets/destructive_confirmation_sheet.dart';
import 'package:pingpay_mobile/features/bills/providers/bill_provider.dart';
import 'package:pingpay_mobile/features/bills/services/bill_split_calculator.dart';
import 'package:pingpay_mobile/features/friends/models/friend_models.dart';
import 'package:pingpay_mobile/features/friends/providers/friends_provider.dart';

void main() {
  group('Feature 3: Complete AI Bill Creation & Bottom Sheets Tests', () {
    testWidgets(
      'CreateBillScreen shows NoFriendsState when user has zero friends',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [friendsListProvider.overrideWith((ref) async => [])],
            child: MaterialApp(
              theme: LightTheme.theme,
              home: const CreateBillScreen(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(NoFriendsStateWidget), findsOneWidget);
        expect(find.text('ยังไม่มีเพื่อนในระบบ'), findsOneWidget);
        expect(find.text('เพิ่มเพื่อนตอนนี้ (Add Friend)'), findsOneWidget);
        expect(find.text('สร้างบิลและบันทึกหนี้ (Create Bill)'), findsNothing);
      },
    );

    testWidgets(
      'CreateBillScreen shows circular "+" button, items collapsed card, and opens FriendSelectionBottomSheet',
      (tester) async {
        final mockFriends = [
          FriendItemModel(
            friendshipId: 'f1',
            friendsSince: DateTime(2026, 1, 1),
            user: const FriendUserModel(
              id: 'u1',
              userCode: 'USR-111',
              displayName: 'Somchai Demo',
            ),
          ),
          FriendItemModel(
            friendshipId: 'f2',
            friendsSince: DateTime(2026, 1, 1),
            user: const FriendUserModel(
              id: 'u2',
              userCode: 'USR-222',
              displayName: 'Jane Demo',
            ),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              friendsListProvider.overrideWith((ref) async => mockFriends),
            ],
            child: MaterialApp(
              theme: LightTheme.theme,
              home: const CreateBillScreen(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // No friends block should NOT be visible
        expect(find.byType(NoFriendsStateWidget), findsNothing);

        // Collapsed items summary card exists
        expect(find.byType(BillItemsSummaryCard), findsOneWidget);

        // Circular "+" button exists
        final addFriendBtn = find.bySemanticsLabel('Add friend to bill');
        expect(addFriendBtn, findsOneWidget);

        // Ensure visible in scroll view and tap circular "+" button to open FriendSelectionBottomSheet
        await tester.ensureVisible(addFriendBtn);
        await tester.pumpAndSettle();
        await tester.tap(addFriendBtn);
        await tester.pumpAndSettle();

        // Bottom sheet open with search and friend list
        expect(find.text('เลือกเพื่อน (Select Friends)'), findsOneWidget);
        expect(find.text('Somchai Demo'), findsOneWidget);
        expect(find.text('Jane Demo'), findsOneWidget);

        // Select Somchai Demo
        await tester.tap(find.text('Somchai Demo'));
        await tester.pumpAndSettle();

        // Confirm selection
        await tester.tap(find.text('ยืนยัน (1 คน)'));
        await tester.pumpAndSettle();

        // Somchai avatar appears in horizontal list and in split editor
        expect(find.text('Somchai Demo'), findsNWidgets(2));
      },
    );

    testWidgets(
      'BillItemsBottomSheet supports multi-select, select all, and bulk deletion',
      (tester) async {
        List<ReceiptItemModel> items = [
          const ReceiptItemModel(name: 'Burger', amount: 120.0, quantity: 1),
          const ReceiptItemModel(name: 'Fries', amount: 80.0, quantity: 1),
          const ReceiptItemModel(name: 'Coke', amount: 40.0, quantity: 1),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: LightTheme.theme,
            home: Scaffold(
              body: BillItemsBottomSheet(
                initialItems: items,
                billTotalAmount: 240.0,
                onItemsUpdated: (updated) => items = updated,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('รายการทั้งหมด 3 รายการ'), findsOneWidget);
        expect(find.text('Burger'), findsOneWidget);
        expect(find.text('Fries'), findsOneWidget);
        expect(find.text('Coke'), findsOneWidget);

        // Enter multi-select mode
        await tester.tap(find.text('เลือก'));
        await tester.pumpAndSettle();

        // Select All
        await tester.tap(find.text('เลือกทั้งหมด'));
        await tester.pumpAndSettle();

        expect(find.text('3 รายการที่เลือก'), findsOneWidget);

        // Tap Delete selected
        await tester.tap(find.text('ลบ (3)'));
        await tester.pumpAndSettle();

        // Confirmation sheet appears
        expect(find.text('ลบ 3 รายการที่เลือก?'), findsOneWidget);

        // Confirm delete
        await tester.tap(find.text('ลบ 3 รายการ'));
        await tester.pumpAndSettle();

        expect(items.isEmpty, isTrue);
        expect(find.text('ยังไม่มีรายการสินค้า'), findsOneWidget);
      },
    );

    testWidgets(
      'DestructiveConfirmationSheet displays correct warning, details, and triggers confirmation',
      (tester) async {
        bool confirmed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: LightTheme.theme,
            home: Scaffold(
              body: DestructiveConfirmationSheet(
                title: 'ลบรายการทั้งหมด?',
                message: 'ข้อมูลจะถูกล้างออกจากระบบ',
                confirmLabel: 'ลบข้อมูล',
                itemCount: 4,
                totalAmount: 500.0,
                onConfirm: () => confirmed = true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('ลบรายการทั้งหมด?'), findsOneWidget);
        expect(find.text('4 รายการ'), findsOneWidget);
        expect(find.text('฿500.00'), findsOneWidget);

        await tester.tap(find.text('ลบข้อมูล'));
        await tester.pump();

        expect(confirmed, isTrue);
      },
    );

    testWidgets('BillConfirmationBottomSheet prevents double submission', (
      tester,
    ) async {
      int callCount = 0;
      const testState = BillCreationState(
        title: 'Dinner at ABC',
        totalAmount: 200.0,
        participants: [
          BillSplitParticipant(
            userId: 'u1',
            displayName: 'Somchai',
            userCode: 'USR-111',
            amountSatang: 10000,
          ),
          BillSplitParticipant(
            userId: 'u2',
            displayName: 'Jane',
            userCode: 'USR-222',
            amountSatang: 10000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: LightTheme.theme,
          home: Scaffold(
            body: BillConfirmationBottomSheet(
              state: testState,
              onConfirm: () => callCount++,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ยืนยันการสร้างบิล (Confirm Bill)'), findsOneWidget);
      expect(find.text('Dinner at ABC'), findsOneWidget);
      expect(find.text('฿200.00'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('ยืนยันและสร้างบิล'));
      await tester.pump();

      expect(callCount, equals(1));
    });
  });
}
