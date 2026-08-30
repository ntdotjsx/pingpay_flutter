import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/bills/models/nli_bill_result_model.dart';
import 'package:pingpay_mobile/features/bills/presentation/widgets/nli_bill_input_bottom_sheet.dart';
import 'package:pingpay_mobile/features/friends/models/friend_models.dart';

void main() {
  testWidgets('NliBillInputBottomSheet renders UI, samples, and live preview on input', (tester) async {
    final mockFriends = [
      const FriendUserModel(
        id: 'friend-1',
        userCode: 'USR-BAS',
        displayName: 'ธนพล',
      ),
      const FriendUserModel(
        id: 'friend-2',
        userCode: 'USR-M',
        displayName: 'วสันต์',
      ),
    ];

    final customNicknames = {
      'friend-1': 'บาส',
      'friend-2': 'เอ็มมี่',
    };

    NliParsedBill? appliedBill;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  NliBillInputBottomSheet.show(
                    context: context,
                    userFriends: mockFriends,
                    friendNicknames: customNicknames,
                    onApplyParsedBill: (parsed) {
                      appliedBill = parsed;
                    },
                  );
                },
                child: const Text('Open NLI'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to open sheet
    await tester.tap(find.text('Open NLI'));
    await tester.pumpAndSettle();

    // Verify Title & Input
    expect(find.text('พิมพ์สั่งสร้างบิลด้วย AI (NLI)'), findsOneWidget);
    expect(find.text('นำข้อมูลไปใส่ในบิล'), findsOneWidget);

    // Enter prompt with line items and friend nickname
    await tester.enterText(find.byType(TextField), 'กินชาบู 1200 มีเนื้อ 500 ผัก 200 น้ำ 100 หารกับ บาส');
    await tester.pumpAndSettle();

    // Verify Live Preview Card displays parsed title, amount, line items, and matched friend nickname
    expect(find.text('ผลการวิเคราะห์ (Live Preview)'), findsOneWidget);
    expect(find.text('กินชาบู'), findsOneWidget);
    expect(find.text('฿1,200.00'), findsOneWidget);
    expect(find.text('บาส'), findsOneWidget);
    expect(find.text('เนื้อ'), findsOneWidget);
    expect(find.text('ผัก'), findsOneWidget);
    expect(find.text('น้ำ'), findsOneWidget);

    // Tap Apply Button
    await tester.tap(find.text('นำข้อมูลไปใส่ในบิล'));
    await tester.pumpAndSettle();

    // Verify applied callback was triggered with extracted items and friend
    expect(appliedBill, isNotNull);
    expect(appliedBill!.title, 'กินชาบู');
    expect(appliedBill!.totalAmount, 1200.0);
    expect(appliedBill!.items.length, 3);
    expect(appliedBill!.matchedParticipants.length, 1);
    expect(appliedBill!.matchedParticipants.first.effectiveDisplayName, 'บาส');
  });
}
