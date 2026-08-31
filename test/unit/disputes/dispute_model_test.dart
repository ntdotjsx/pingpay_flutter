import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/disputes/models/dispute_model.dart';

void main() {
  group('DisputeModel & Status parsing', () {
    test('should parse dispute statuses correctly', () {
      expect(parseDisputeStatus('open'), DisputeStatus.open);
      expect(parseDisputeStatus('under_review'), DisputeStatus.underReview);
      expect(parseDisputeStatus('resolved_paid'), DisputeStatus.resolvedPaid);
      expect(parseDisputeStatus('resolved_written_off'), DisputeStatus.resolvedWrittenOff);
      expect(parseDisputeStatus('resolved_rejected'), DisputeStatus.resolvedRejected);
      expect(parseDisputeStatus('unknown'), DisputeStatus.open);
    });

    test('should serialize and deserialize DisputeModel from JSON with creditor evidence', () {
      final json = {
        'id': 'disp-001',
        'billItemId': 'item-001',
        'raisedById': 'user-debtor-01',
        'reason': 'คิดเงินเกิน 100 บาท',
        'evidenceUrl': 'https://example.com/receipt.jpg',
        'status': 'under_review',
        'creditorEvidenceNote': 'ยอดเงินถูกต้องตามใบเสร็จที่แนบ',
        'creditorEvidenceUrl': 'https://example.com/creditor_receipt.jpg',
        'creditorRespondedAt': '2026-08-31T12:00:00.000Z',
        'createdAt': '2026-08-31T10:00:00.000Z',
        'isDebtor': true,
        'isCreditor': false,
      };

      final model = DisputeModel.fromJson(json);
      expect(model.id, 'disp-001');
      expect(model.billItemId, 'item-001');
      expect(model.reason, 'คิดเงินเกิน 100 บาท');
      expect(model.status, DisputeStatus.underReview);
      expect(model.creditorEvidenceNote, 'ยอดเงินถูกต้องตามใบเสร็จที่แนบ');
      expect(model.creditorEvidenceUrl, 'https://example.com/creditor_receipt.jpg');
      expect(model.creditorRespondedAt, isNotNull);
      expect(model.isDebtor, isTrue);
      expect(model.isCreditor, isFalse);

      final serialized = model.toJson();
      expect(serialized['id'], 'disp-001');
      expect(serialized['status'], 'under_review');
      expect(serialized['creditorEvidenceNote'], 'ยอดเงินถูกต้องตามใบเสร็จที่แนบ');
    });
  });
}
