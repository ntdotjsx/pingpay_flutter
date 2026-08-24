import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return NotificationRepository(client);
});

class NotificationRepository {
  final DioClient _client;

  NotificationRepository(this._client);

  /// Fetch user notifications from backend Outbox (/api/v1/notifications/user/:userId)
  Future<List<AppNotificationItem>> getUserNotifications(String userId, {int limit = 50}) async {
    try {
      final response = await _client.get('/api/v1/notifications/user/$userId?limit=$limit');
      final data = response.data;

      if (data is Map<String, dynamic> && data['notifications'] is List) {
        final rawList = data['notifications'] as List;
        return rawList.map((json) => _mapBackendNotificationToItem(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching notifications from backend: $e');
      return [];
    }
  }

  AppNotificationItem _mapBackendNotificationToItem(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final eventType = json['eventType']?.toString() ?? '';
    final payload = (json['payload'] is Map) ? Map<String, dynamic>.from(json['payload'] as Map) : <String, dynamic>{};
    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final status = json['status']?.toString() ?? 'SENT';

    NotificationType type = NotificationType.systemGeneral;
    String title = 'การแจ้งเตือน';
    String body = '';
    double? amount;
    String? relatedId;

    switch (eventType) {
      case 'BILL_CREATED':
        type = NotificationType.debtRequest;
        title = 'มีคำขอรับสภาพหนี้ใหม่ 🧾';
        final billTitle = payload['billTitle'] ?? 'บิลค่าใช้จ่าย';
        final creatorName = payload['creatorName'] ?? 'เพื่อน';
        final debtAmt = payload['participantDebtAmount']?.toString() ?? '0';
        body = '$creatorName เพิ่มคุณในบิล "$billTitle" ยอดค้าง ฿$debtAmt';
        amount = double.tryParse(debtAmt);
        relatedId = payload['billId']?.toString();
        break;

      case 'BILL_UPDATED':
        type = NotificationType.debtRequest;
        title = 'บิลได้รับการแก้ไข 📝';
        final billTitle = payload['billTitle'] ?? 'บิล';
        final newAmount = payload['newAmount']?.toString() ?? '';
        body = 'บิล "$billTitle" มีการปรับปรุงยอดเป็น ฿$newAmount';
        amount = double.tryParse(newAmount);
        relatedId = payload['billId']?.toString();
        break;

      case 'BILL_WRITTEN_OFF':
        type = NotificationType.paymentConfirmed;
        title = 'ยอดหนี้ได้รับการหักลบ/ยกหนี้ 🤝';
        final billTitle = payload['billTitle'] ?? 'บิล';
        final actorName = payload['actorName'] ?? 'เจ้าของบิล';
        final writtenOff = payload['writtenOffAmount']?.toString() ?? '0';
        body = '$actorName ได้หักลบหนี้ให้คุณ ฿$writtenOff สำหรับบิล "$billTitle"';
        amount = double.tryParse(writtenOff);
        relatedId = payload['billId']?.toString();
        break;

      case 'BILL_CANCELLED':
        type = NotificationType.systemGeneral;
        title = 'บิลถูกยกเลิกแล้ว ❌';
        final billTitle = payload['billTitle'] ?? 'บิล';
        body = 'บิล "$billTitle" ถูกยกเลิกโดยผู้สร้าง';
        relatedId = payload['billId']?.toString();
        break;

      case 'PAYMENT_PENDING_CONFIRMATION':
        type = NotificationType.paymentReceived;
        title = 'เพื่อนส่งสลิปชำระเงินแล้ว 💸';
        final billTitle = payload['billTitle'] ?? 'บิล';
        final debtorName = payload['debtorName'] ?? 'เพื่อน';
        final paidAmt = payload['amount']?.toString() ?? '0';
        body = '$debtorName ได้ชำระเงิน ฿$paidAmt สำหรับบิล "$billTitle"';
        amount = double.tryParse(paidAmt);
        relatedId = payload['paymentId']?.toString();
        break;

      case 'PAYMENT_CONFIRMED':
        type = NotificationType.paymentConfirmed;
        title = 'การชำระเงินได้รับการยืนยันแล้ว ✅';
        final billTitle = payload['billTitle'] ?? 'บิล';
        final paidAmt = payload['amount']?.toString() ?? '0';
        body = 'ยอดชำระ ฿$paidAmt สำหรับบิล "$billTitle" ได้รับการยืนยันแล้ว';
        amount = double.tryParse(paidAmt);
        relatedId = payload['billId']?.toString();
        break;

      case 'PAYMENT_REJECTED':
        type = NotificationType.systemSecurity;
        title = 'สลิปการชำระเงินถูกปฏิเสธ ⚠️';
        final billTitle = payload['billTitle'] ?? 'บิล';
        final reason = payload['reason'] ?? 'ไม่ตรงกับยอดที่เรียกเก็บ';
        body = 'สลิปสำหรับบิล "$billTitle" ไม่ผ่านการยืนยัน ($reason)';
        relatedId = payload['billId']?.toString();
        break;

      case 'DEBT_WEEKLY_REMINDER':
        type = NotificationType.debtRequest;
        title = 'แจ้งเตือนชำระหนี้ค้างประจำสัปดาห์ ⏳';
        final billTitle = payload['billTitle'] ?? 'บิล';
        final debtAmt = payload['outstandingAmount']?.toString() ?? '0';
        body = 'คุณมียอดค้างชำระ ฿$debtAmt สำหรับบิล "$billTitle"';
        amount = double.tryParse(debtAmt);
        relatedId = payload['billId']?.toString();
        break;

      case 'FRIEND_REQUEST_RECEIVED':
        type = NotificationType.friendRequest;
        title = 'มีคำขอเป็นเพื่อนใหม่ 👥';
        final senderName = payload['senderName'] ?? 'ผู้ใช้งาน';
        body = '$senderName ส่งคำขอเป็นเพื่อนถึงคุณ';
        relatedId = payload['friendshipId']?.toString();
        break;

      case 'FRIEND_REQUEST_ACCEPTED':
        type = NotificationType.friendAdded;
        title = 'ยอมรับคำขอเป็นเพื่อนแล้ว ✨';
        final friendName = payload['friendName'] ?? 'เพื่อน';
        body = '$friendName ได้ตอบรับเป็นเพื่อนกับคุณแล้ว';
        relatedId = payload['friendshipId']?.toString();
        break;

      default:
        type = NotificationType.systemGeneral;
        title = payload['title']?.toString() ?? 'การแจ้งเตือนจากระบบ';
        body = payload['body']?.toString() ?? payload['message']?.toString() ?? 'มีการเคลื่อนไหวใหม่ในระบบ';
        break;
    }

    return AppNotificationItem(
      id: id.isNotEmpty ? id : 'backend-${createdAt.millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      isRead: status == 'READ',
      amount: amount,
      relatedId: relatedId,
      metadata: payload,
    );
  }
}
