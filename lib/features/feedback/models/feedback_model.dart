import 'package:flutter/material.dart';

enum FeedbackType {
  bugReport('BUG_REPORT', 'แจ้งปัญหา / บั๊ก', Icons.bug_report_rounded, Color(0xFFEF4444)),
  feedback('FEEDBACK', 'ข้อเสนอแนะ', Icons.chat_bubble_outline_rounded, Color(0xFFFF5000)),
  featureRequest('FEATURE_REQUEST', 'ขอฟีเจอร์ใหม่', Icons.lightbulb_outline_rounded, Color(0xFF6366F1)),
  other('OTHER', 'เรื่องอื่น ๆ', Icons.help_outline_rounded, Color(0xFF64748B));

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const FeedbackType(this.value, this.label, this.icon, this.color);

  static FeedbackType fromValue(String? val) {
    return FeedbackType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => FeedbackType.feedback,
    );
  }
}

enum FeedbackSeverity {
  low('LOW', 'ต่ำ (เล็กน้อย)', Color(0xFF10B981)),
  medium('MEDIUM', 'ปานกลาง', Color(0xFFF59E0B)),
  high('HIGH', 'สูง (ทำงานผิดพลาด)', Color(0xFFF97316)),
  critical('CRITICAL', 'วิกฤต (แอปค้าง)', Color(0xFFEF4444));

  final String value;
  final String label;
  final Color color;

  const FeedbackSeverity(this.value, this.label, this.color);

  static FeedbackSeverity fromValue(String? val) {
    return FeedbackSeverity.values.firstWhere(
      (e) => e.value == val,
      orElse: () => FeedbackSeverity.low,
    );
  }
}

class CreateFeedbackRequestModel {
  final FeedbackType type;
  final String subject;
  final String description;
  final FeedbackSeverity? severity;
  final int? rating;
  final String? contactEmail;
  final String? appVersion;
  final String? deviceInfo;

  const CreateFeedbackRequestModel({
    required this.type,
    required this.subject,
    required this.description,
    this.severity,
    this.rating,
    this.contactEmail,
    this.appVersion,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'subject': subject.trim(),
      'description': description.trim(),
      if (severity != null) 'severity': severity!.value,
      if (rating != null) 'rating': rating,
      if (contactEmail != null && contactEmail!.trim().isNotEmpty)
        'contactEmail': contactEmail!.trim(),
      if (appVersion != null) 'appVersion': appVersion,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
    };
  }

  factory CreateFeedbackRequestModel.fromJson(Map<String, dynamic> json) {
    return CreateFeedbackRequestModel(
      type: FeedbackType.fromValue(json['type'] as String?),
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      severity: json['severity'] != null
          ? FeedbackSeverity.fromValue(json['severity'] as String?)
          : null,
      rating: json['rating'] as int?,
      contactEmail: json['contactEmail'] as String?,
      appVersion: json['appVersion'] as String?,
      deviceInfo: json['deviceInfo'] as String?,
    );
  }
}
