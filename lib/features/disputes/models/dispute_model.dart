import 'package:flutter/foundation.dart';

enum DisputeStatus {
  open,
  underReview,
  resolvedPaid,
  resolvedWrittenOff,
  resolvedRejected,
}

extension DisputeStatusExtension on DisputeStatus {
  String get value {
    switch (this) {
      case DisputeStatus.open:
        return 'open';
      case DisputeStatus.underReview:
        return 'under_review';
      case DisputeStatus.resolvedPaid:
        return 'resolved_paid';
      case DisputeStatus.resolvedWrittenOff:
        return 'resolved_written_off';
      case DisputeStatus.resolvedRejected:
        return 'resolved_rejected';
    }
  }

  String get labelTh {
    switch (this) {
      case DisputeStatus.open:
        return 'รอดำเนินการ';
      case DisputeStatus.underReview:
        return 'กำลังตรวจสอบ';
      case DisputeStatus.resolvedPaid:
        return 'ตัดสินเป็นชำระแล้ว';
      case DisputeStatus.resolvedWrittenOff:
        return 'ตัดสินเป็นยกหนี้ให้';
      case DisputeStatus.resolvedRejected:
        return 'ปฏิเสธข้อพิพาท';
    }
  }
}

DisputeStatus parseDisputeStatus(String? value) {
  switch (value) {
    case 'open':
      return DisputeStatus.open;
    case 'under_review':
      return DisputeStatus.underReview;
    case 'resolved_paid':
      return DisputeStatus.resolvedPaid;
    case 'resolved_written_off':
      return DisputeStatus.resolvedWrittenOff;
    case 'resolved_rejected':
      return DisputeStatus.resolvedRejected;
    default:
      return DisputeStatus.open;
  }
}

class DisputeModel {
  final String id;
  final String billItemId;
  final String raisedById;
  final String reason;
  final String? evidenceUrl;
  final DisputeStatus status;

  // Creditor Counter-Evidence
  final String? creditorEvidenceNote;
  final String? creditorEvidenceUrl;
  final DateTime? creditorRespondedAt;

  // Resolution
  final String? resolvedById;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  // Nested relation metadata (if populated)
  final Map<String, dynamic>? billItem;
  final Map<String, dynamic>? raisedBy;
  final bool isDebtor;
  final bool isCreditor;

  DisputeModel({
    required this.id,
    required this.billItemId,
    required this.raisedById,
    required this.reason,
    this.evidenceUrl,
    required this.status,
    this.creditorEvidenceNote,
    this.creditorEvidenceUrl,
    this.creditorRespondedAt,
    this.resolvedById,
    this.resolutionNote,
    this.resolvedAt,
    required this.createdAt,
    this.billItem,
    this.raisedBy,
    this.isDebtor = false,
    this.isCreditor = false,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    return DisputeModel(
      id: json['id']?.toString() ?? '',
      billItemId: json['billItemId']?.toString() ?? json['bill_item_id']?.toString() ?? '',
      raisedById: json['raisedById']?.toString() ?? json['raised_by_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      evidenceUrl: json['evidenceUrl']?.toString() ?? json['evidence_url']?.toString(),
      status: parseDisputeStatus(json['status']?.toString()),
      creditorEvidenceNote: json['creditorEvidenceNote']?.toString() ?? json['creditor_evidence_note']?.toString(),
      creditorEvidenceUrl: json['creditorEvidenceUrl']?.toString() ?? json['creditor_evidence_url']?.toString(),
      creditorRespondedAt: json['creditorRespondedAt'] != null
          ? DateTime.tryParse(json['creditorRespondedAt'].toString())
          : (json['creditor_responded_at'] != null ? DateTime.tryParse(json['creditor_responded_at'].toString()) : null),
      resolvedById: json['resolvedById']?.toString() ?? json['resolved_by_id']?.toString(),
      resolutionNote: json['resolutionNote']?.toString() ?? json['resolution_note']?.toString(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : (json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      billItem: json['billItem'] as Map<String, dynamic>?,
      raisedBy: json['raisedBy'] as Map<String, dynamic>?,
      isDebtor: json['isDebtor'] == true,
      isCreditor: json['isCreditor'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'billItemId': billItemId,
      'raisedById': raisedById,
      'reason': reason,
      'evidenceUrl': evidenceUrl,
      'status': status.value,
      'creditorEvidenceNote': creditorEvidenceNote,
      'creditorEvidenceUrl': creditorEvidenceUrl,
      'creditorRespondedAt': creditorRespondedAt?.toIso8601String(),
      'resolvedById': resolvedById,
      'resolutionNote': resolutionNote,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isDebtor': isDebtor,
      'isCreditor': isCreditor,
    };
  }
}
