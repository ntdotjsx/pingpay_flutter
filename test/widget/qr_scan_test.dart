import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/friends/screens/qr_scan_friend_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QrScanFriendScreen renders UI elements and top navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QrScanFriendScreen(),
        ),
      ),
    );

    // Initial render
    await tester.pump();

    // Verify Title Badge
    expect(find.text('สแกน QR เพิ่มเพื่อน'), findsOneWidget);

    // Verify Instruction Text
    expect(find.text('วาง QR Code ให้อยู่ในกรอบเพื่อตรวจจับอัตโนมัติ'), findsOneWidget);

    // Verify Gallery Picker Button
    expect(find.text('เลือกรูป QR Code จากคลังภาพ'), findsOneWidget);
  });
}
