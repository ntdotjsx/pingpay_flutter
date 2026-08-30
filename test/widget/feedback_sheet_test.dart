import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/core/theme/theme.dart';
import 'package:pingpay_mobile/core/widgets/app_button.dart';
import 'package:pingpay_mobile/features/auth/models/auth_models.dart';
import 'package:pingpay_mobile/features/auth/providers/auth_provider.dart';
import 'package:pingpay_mobile/features/feedback/data/feedback_repository.dart';
import 'package:pingpay_mobile/features/feedback/models/feedback_model.dart';
import 'package:pingpay_mobile/features/feedback/presentation/feedback_bottom_sheet.dart';

class MockFeedbackRepository implements FeedbackRepository {
  CreateFeedbackRequestModel? lastSubmittedRequest;
  bool shouldSucceed = true;

  @override
  Future<Map<String, dynamic>> sendFeedback(CreateFeedbackRequestModel request) async {
    lastSubmittedRequest = request;
    if (!shouldSucceed) {
      throw Exception('Network error');
    }
    return {
      'success': true,
      'message': 'ส่งข้อเสนอแนะเรียบร้อยแล้ว ขอบคุณครับ!',
    };
  }
}

void main() {
  group('FeedbackBottomSheet Widget Tests', () {
    late MockFeedbackRepository mockRepo;

    setUp(() {
      mockRepo = MockFeedbackRepository();
    });

    testWidgets('Renders header, category chips, inputs, and diagnostics banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: LightTheme.theme,
            home: const Scaffold(
              body: FeedbackBottomSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and Discord badge
      expect(find.text('ส่งข้อเสนอแนะ & แจ้งปัญหา'), findsOneWidget);
      expect(find.text('Discord Live'), findsOneWidget);

      // Check Category Chips
      expect(find.text('แจ้งปัญหา / บั๊ก'), findsOneWidget);
      expect(find.text('ข้อเสนอแนะ'), findsOneWidget);
      expect(find.text('ขอฟีเจอร์ใหม่'), findsOneWidget);
      expect(find.text('เรื่องอื่น ๆ'), findsOneWidget);

      // Check Severity chips for Bug Report (default)
      expect(find.text('ระดับความรุนแรงของปัญหา'), findsOneWidget);
      expect(find.text('ต่ำ (เล็กน้อย)'), findsOneWidget);
      expect(find.text('ปานกลาง'), findsOneWidget);
      expect(find.text('สูง (ทำงานผิดพลาด)'), findsOneWidget);
      expect(find.text('วิกฤต (แอปค้าง)'), findsOneWidget);

      // Check Subject, Description, Submit button
      expect(find.text('หัวข้อข้อความ *'), findsOneWidget);
      expect(find.text('รายละเอียด *'), findsOneWidget);
      expect(find.text('ส่งข้อความไปยัง Discord'), findsOneWidget);
    });

    testWidgets('Switches category to Feedback and displays star rating', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: LightTheme.theme,
            home: const Scaffold(
              body: FeedbackBottomSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on 'ข้อเสนอแนะ' chip
      await tester.tap(find.text('ข้อเสนอแนะ'));
      await tester.pumpAndSettle();

      // Check that Star Rating is now visible
      expect(find.text('คะแนนความพึงพอใจต่อ PingPay'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    });

    testWidgets('Auto-fills user email from AuthState and displays badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockUser = UserModel(
        id: 'usr_1',
        userCode: 'USR-60CE13',
        displayName: 'นัท พัฒนาการ',
        email: 'nat@pingpay.com',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
            authStateProvider.overrideWith(
              (ref) => AuthNotifier(ref.read(authRepositoryProvider))
                ..state = AuthState(
                  status: AuthStatus.authenticated,
                  user: mockUser,
                ),
            ),
          ],
          child: MaterialApp(
            theme: LightTheme.theme,
            home: const Scaffold(
              body: FeedbackBottomSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check auto-filled badge and email text in field
      expect(find.text('ดึงจากบัญชีอัตโนมัติ'), findsOneWidget);
      expect(find.text('nat@pingpay.com'), findsOneWidget);
    });

    testWidgets('Validates required fields and submits to mock repository', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: LightTheme.theme,
            home: const Scaffold(
              body: FeedbackBottomSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Try submitting without filling required fields
      await tester.ensureVisible(find.byType(AppButton));
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('กรุณาระบุหัวข้ออย่างน้อย 2 ตัวอักษร'), findsOneWidget);

      // Enter Subject and Description
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'ทดสอบแจ้งบั๊ก');
      await tester.enterText(textFields.at(1), 'รายละเอียดการเกิดข้อผิดพลาดในการคำนวณบิล');

      // Submit
      await tester.ensureVisible(find.byType(AppButton));
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(mockRepo.lastSubmittedRequest, isNotNull);
      expect(mockRepo.lastSubmittedRequest!.subject, 'ทดสอบแจ้งบั๊ก');
      expect(mockRepo.lastSubmittedRequest!.description, 'รายละเอียดการเกิดข้อผิดพลาดในการคำนวณบิล');
      expect(mockRepo.lastSubmittedRequest!.type, FeedbackType.bugReport);
    });
  });
}
