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
    this.createdAt,
    this.updatedAt,
    this.debtor,
  });

  double get outstandingAmount {
    final remaining = currentAmount - amountPaid - amountWrittenOff;
    return remaining > 0 ? remaining : 0.0;
  }

  bool get isFullyPaid => status == 'paid' || amountPaid >= currentAmount;
  bool get isFullyWrittenOff => status == 'written_off';

  factory BillItemParticipantModel.fromJson(Map<String, dynamic> json) {
    return BillItemParticipantModel(
      id: json['id'] as String? ?? '',
      billId: json['billId'] as String? ?? '',
      debtorId: json['debtorId'] as String? ?? '',
      originalAmount:
          (json['originalAmount'] as num?)?.toDouble() ??
          (double.tryParse(json['originalAmount']?.toString() ?? '') ?? 0.0),
      currentAmount:
          (json['currentAmount'] as num?)?.toDouble() ??
          (double.tryParse(json['currentAmount']?.toString() ?? '') ?? 0.0),
      amountPaid:
          (json['amountPaid'] as num?)?.toDouble() ??
          (double.tryParse(json['amountPaid']?.toString() ?? '') ?? 0.0),
      amountWrittenOff:
          (json['amountWrittenOff'] as num?)?.toDouble() ??
          (double.tryParse(json['amountWrittenOff']?.toString() ?? '') ?? 0.0),
      status: json['status'] as String? ?? 'unpaid',
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
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

class BillModel {
  final String id;
  final String ownerId;
  final String? title;
  final String? description;
  final double totalAmount;
  final String currency;
  final String? groupId;
  final String
  status; // unpaid, partially_paid, fully_paid, partially_written_off, fully_written_off
  final dynamic itemsBreakdown;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<BillItemParticipantModel> items;
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
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.owner,
  });

  double get totalPaidAmount =>
      items.fold(0.0, (acc, item) => acc + item.amountPaid);
  double get totalWrittenOffAmount =>
      items.fold(0.0, (acc, item) => acc + item.amountWrittenOff);
  double get totalOutstandingAmount =>
      items.fold(0.0, (acc, item) => acc + item.outstandingAmount);

  factory BillModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List?) ?? [];
    return BillModel(
      id: json['id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      totalAmount:
          (json['totalAmount'] as num?)?.toDouble() ??
          (double.tryParse(json['totalAmount']?.toString() ?? '') ?? 0.0),
      currency: json['currency'] as String? ?? 'THB',
      groupId: json['groupId'] as String?,
      status: json['status'] as String? ?? 'unpaid',
      itemsBreakdown: json['itemsBreakdown'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      items: itemsList
          .map(
            (e) => BillItemParticipantModel.fromJson(e as Map<String, dynamic>),
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
    'items': items.map((e) => e.toJson()).toList(),
  };
}
