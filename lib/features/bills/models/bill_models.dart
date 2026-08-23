double _asDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class BillItemParticipantModel {
  final String id;
  final String billId;
  final String debtorId;
  final double originalAmount;
  final double currentAmount;
  final double amountPaid;
  final double amountWrittenOff;
  final String status; // unpaid, partially_paid, paid, written_off
  final bool isLocked;
  final bool isAcknowledged;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final BillDebtorUserModel? debtor;

  const BillItemParticipantModel({
    required this.id,
    required this.billId,
    required this.debtorId,
    required this.originalAmount,
    required this.currentAmount,
    this.amountPaid = 0.0,
    this.amountWrittenOff = 0.0,
    required this.status,
    this.isLocked = false,
    this.isAcknowledged = false,
    this.createdAt,
    this.updatedAt,
    this.debtor,
  });

  double get outstandingAmount {
    final remaining = currentAmount - amountPaid - amountWrittenOff;
    return remaining > 0 ? remaining : 0.0;
  }

  bool get isFullyPaid => status == 'paid' || status == 'fully_paid' || amountPaid >= currentAmount;
  bool get isFullyWrittenOff =>
      status == 'written_off' ||
      status == 'fully_written_off' ||
      (amountWrittenOff >= currentAmount && currentAmount > 0);

  factory BillItemParticipantModel.fromJson(Map<String, dynamic> json) {
    return BillItemParticipantModel(
      id: json['id'] as String? ?? '',
      billId: json['billId'] as String? ?? '',
      debtorId: json['debtorId'] as String? ?? '',
      originalAmount: _asDouble(json['originalAmount']),
      currentAmount: _asDouble(json['currentAmount']),
      amountPaid: _asDouble(json['amountPaid']),
      amountWrittenOff: _asDouble(json['amountWrittenOff']),
      status: json['status'] as String? ?? 'unpaid',
      isLocked: json['isLocked'] as bool? ?? false,
      isAcknowledged: json['isAcknowledged'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal()
          : null,
      debtor: json['debtor'] != null
          ? BillDebtorUserModel.fromJson(json['debtor'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'billId': billId,
    'debtorId': debtorId,
    'originalAmount': originalAmount,
    'currentAmount': currentAmount,
    'amountPaid': amountPaid,
    'amountWrittenOff': amountWrittenOff,
    'status': status,
    'isLocked': isLocked,
  };
}

class BillDebtorUserModel {
  final String id;
  final String userCode;
  final String displayName;
  final String? avatarUrl;

  const BillDebtorUserModel({
    required this.id,
    required this.userCode,
    required this.displayName,
    this.avatarUrl,
  });

  factory BillDebtorUserModel.fromJson(Map<String, dynamic> json) {
    return BillDebtorUserModel(
      id: json['id'] as String? ?? '',
      userCode: json['userCode'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'ผู้ใช้งาน',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class BillEditLogModel {
  final String id;
  final String billId;
  final String? billItemId;
  final String performedById;
  final String? affectedUserId;
  final String action; // debt_written_off, bill_cancelled, etc.
  final dynamic previousValue;
  final dynamic newValue;
  final String? note; // Write-off reason / note
  final DateTime? createdAt;
  final BillDebtorUserModel? performedBy;

  const BillEditLogModel({
    required this.id,
    required this.billId,
    this.billItemId,
    required this.performedById,
    this.affectedUserId,
    required this.action,
    this.previousValue,
    this.newValue,
    this.note,
    this.createdAt,
    this.performedBy,
  });

  factory BillEditLogModel.fromJson(Map<String, dynamic> json) {
    return BillEditLogModel(
      id: json['id'] as String? ?? '',
      billId: json['billId'] as String? ?? '',
      billItemId: json['billItemId'] as String?,
      performedById: json['performedById'] as String? ?? '',
      affectedUserId: json['affectedUserId'] as String?,
      action: json['action'] as String? ?? '',
      previousValue: json['previousValue'],
      newValue: json['newValue'],
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
      performedBy: json['performedBy'] != null
          ? BillDebtorUserModel.fromJson(json['performedBy'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BillModel {
  final String id;
  final String ownerId;
  final String? title;
  final String? description;
  final double totalAmount;
  final String currency;
  final String? groupId;
  final String
  status; // unpaid, partially_paid, fully_paid, partially_written_off, fully_written_off, cancelled
  final dynamic itemsBreakdown;
  final String? receiptImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<BillItemParticipantModel> items;
  final List<BillEditLogModel> editLogs;
  final BillDebtorUserModel? owner;

  const BillModel({
    required this.id,
    required this.ownerId,
    this.title,
    this.description,
    required this.totalAmount,
    this.currency = 'THB',
    this.groupId,
    required this.status,
    this.itemsBreakdown,
    this.receiptImageUrl,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.editLogs = const [],
    this.owner,
  });

  bool get isCancelled => status == 'cancelled' || status == 'canceled';
  bool get isFullyWrittenOff =>
      status == 'fully_written_off' ||
      status == 'written_off' ||
      (items.isNotEmpty && items.every((i) => i.isFullyWrittenOff));
  bool get isFullyPaid =>
      status == 'paid' ||
      status == 'fully_paid' ||
      (items.isNotEmpty && items.every((i) => i.isFullyPaid));
  bool get isFullySettled => isFullyPaid || isFullyWrittenOff || isCancelled || totalOutstandingAmount <= 0;

  /// Find write-off reason for a specific participant item if available
  String? getWriteOffReasonForParticipant(String participantId) {
    // 1. Try finding in editLogs
    final log = editLogs.where((l) =>
      (l.action == 'debt_written_off' || l.action == 'write_off') &&
      l.billItemId == participantId &&
      l.note != null &&
      l.note!.trim().isNotEmpty
    ).firstOrNull;
    if (log != null && log.note != null && log.note!.trim().isNotEmpty) {
      return log.note!.trim();
    }

    // 2. Fallback to general write-off log on this bill
    final generalLog = editLogs.where((l) =>
      (l.action == 'debt_written_off' || l.action == 'write_off') &&
      l.note != null &&
      l.note!.trim().isNotEmpty
    ).firstOrNull;
    return generalLog?.note?.trim();
  }

  double get totalDebtorsAmount =>
      items.fold(0.0, (acc, item) => acc + item.currentAmount);
  double get myShare {
    final diff = totalAmount - totalDebtorsAmount;
    return diff > 0.009 ? diff : 0.0;
  }
  bool get hasMyShare => myShare > 0.009;
  double get totalPaidAmount =>
      items.fold(0.0, (acc, item) => acc + item.amountPaid);
  double get totalWrittenOffAmount =>
      items.fold(0.0, (acc, item) => acc + item.amountWrittenOff);
  double get totalOutstandingAmount =>
      items.fold(0.0, (acc, item) => acc + item.outstandingAmount);

  factory BillModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List?) ?? [];
    final editLogsList = (json['editLogs'] as List?) ?? [];
    return BillModel(
      id: json['id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      totalAmount: _asDouble(json['totalAmount']),
      currency: json['currency'] as String? ?? 'THB',
      groupId: json['groupId'] as String?,
      status: json['status'] as String? ?? 'unpaid',
      itemsBreakdown: json['itemsBreakdown'],
      receiptImageUrl: json['receiptImageUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal()
          : null,
      items: itemsList
          .map(
            (e) => BillItemParticipantModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      editLogs: editLogsList
          .map(
            (e) => BillEditLogModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      owner: json['owner'] != null
          ? BillDebtorUserModel.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'title': title,
    'description': description,
    'totalAmount': totalAmount,
    'currency': currency,
    'status': status,
    'receiptImageUrl': receiptImageUrl,
    'items': items.map((e) => e.toJson()).toList(),
  };
}
