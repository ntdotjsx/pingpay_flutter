import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/feedback/models/feedback_model.dart';

void main() {
  group('Feedback Models & Enum Tests', () {
    test('FeedbackType maps labels and colors accurately', () {
      expect(FeedbackType.bugReport.value, 'BUG_REPORT');
      expect(FeedbackType.feedback.value, 'FEEDBACK');
      expect(FeedbackType.featureRequest.value, 'FEATURE_REQUEST');
      expect(FeedbackType.other.value, 'OTHER');

      expect(FeedbackType.fromValue('BUG_REPORT'), FeedbackType.bugReport);
      expect(FeedbackType.fromValue('FEEDBACK'), FeedbackType.feedback);
      expect(FeedbackType.fromValue('UNKNOWN'), FeedbackType.feedback); // fallback
    });

    test('FeedbackSeverity maps values and handles fallback', () {
      expect(FeedbackSeverity.critical.value, 'CRITICAL');
      expect(FeedbackSeverity.high.value, 'HIGH');
      expect(FeedbackSeverity.medium.value, 'MEDIUM');
      expect(FeedbackSeverity.low.value, 'LOW');

      expect(FeedbackSeverity.fromValue('CRITICAL'), FeedbackSeverity.critical);
      expect(FeedbackSeverity.fromValue('UNKNOWN'), FeedbackSeverity.low);
    });

    test('CreateFeedbackRequestModel serializes to JSON correctly for Bug Report', () {
      final req = CreateFeedbackRequestModel(
        type: FeedbackType.bugReport,
        subject: 'ปุ่มบันทึกไม่ตอบสนอง',
        description: 'เมื่อกดปุ่มบันทึกบิลแล้วไม่เกิดอะไรขึ้น',
        severity: FeedbackSeverity.high,
        contactEmail: 'user@example.com',
        appVersion: 'v1.0.0 (1)',
        deviceInfo: 'iPhone 15 Pro',
      );

      final json = req.toJson();

      expect(json['type'], 'BUG_REPORT');
      expect(json['subject'], 'ปุ่มบันทึกไม่ตอบสนอง');
      expect(json['description'], 'เมื่อกดปุ่มบันทึกบิลแล้วไม่เกิดอะไรขึ้น');
      expect(json['severity'], 'HIGH');
      expect(json['contactEmail'], 'user@example.com');
      expect(json['appVersion'], 'v1.0.0 (1)');
      expect(json['deviceInfo'], 'iPhone 15 Pro');
      expect(json.containsKey('rating'), false);
    });

    test('CreateFeedbackRequestModel serializes to JSON correctly for Feedback with rating', () {
      final req = CreateFeedbackRequestModel(
        type: FeedbackType.feedback,
        subject: 'บริการดีมาก',
        description: 'ใช้งานสะดวกมาก ชอบระบบหารเงิน',
        rating: 5,
      );

      final json = req.toJson();

      expect(json['type'], 'FEEDBACK');
      expect(json['subject'], 'บริการดีมาก');
      expect(json['rating'], 5);
      expect(json.containsKey('severity'), false);
    });

    test('CreateFeedbackRequestModel deserializes from JSON correctly', () {
      final json = {
        'type': 'FEATURE_REQUEST',
        'subject': 'ขอธีมสีฟ้า',
        'description': 'อยากได้ธีมสีฟ้าสดใส',
        'appVersion': '1.0.0',
      };

      final model = CreateFeedbackRequestModel.fromJson(json);

      expect(model.type, FeedbackType.featureRequest);
      expect(model.subject, 'ขอธีมสีฟ้า');
      expect(model.description, 'อยากได้ธีมสีฟ้าสดใส');
      expect(model.appVersion, '1.0.0');
      expect(model.severity, isNull);
      expect(model.rating, isNull);
    });
  });
}
