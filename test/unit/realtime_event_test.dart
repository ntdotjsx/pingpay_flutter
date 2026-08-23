import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/core/realtime/realtime_event.dart';

void main() {
  group('RealtimeEvent', () {
    test('parses typed event payload safely', () {
      final event = RealtimeEvent.fromJson({
        'type': 'bill.created',
        'eventId': 'evt-1',
        'timestamp': '2026-08-24T00:00:00.000Z',
        'resourceId': 'bill-1',
        'version': 1,
        'data': {'billId': 'bill-1'},
      });

      expect(event.type, 'bill.created');
      expect(event.eventId, 'evt-1');
      expect(event.resourceId, 'bill-1');
      expect(event.data['billId'], 'bill-1');
    });
  });

  group('RealtimeEventDeduper', () {
    test('ignores duplicate event ids', () {
      final deduper = RealtimeEventDeduper();
      final event = RealtimeEvent.fromJson({
        'type': 'friend.request.created',
        'eventId': 'same-event',
        'timestamp': '2026-08-24T00:00:00.000Z',
        'data': {'requestId': 'request-1'},
      });

      expect(deduper.shouldProcess(event), isTrue);
      expect(deduper.shouldProcess(event), isFalse);
    });

    test('allows events without ids to avoid dropping malformed server data', () {
      final deduper = RealtimeEventDeduper();
      final event = RealtimeEvent.fromJson({
        'type': 'sync.required',
        'timestamp': '2026-08-24T00:00:00.000Z',
        'data': {},
      });

      expect(deduper.shouldProcess(event), isTrue);
      expect(deduper.shouldProcess(event), isTrue);
    });
  });
}
