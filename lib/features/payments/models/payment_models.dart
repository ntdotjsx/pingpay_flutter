double _asDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

int _asInt(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? 0;
  return 0;
}

int? _asOptionalInt(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val);
  return null;
}

bool _asBool(dynamic val) {
  if (val == null) return false;
  if (val is bool) return val;
  if (val is num) return val == 1;
  if (val is String) {
    final s = val.toLowerCase().trim();
    return s == 'true' || s == '1' || s == 't';
  }
  return false;
}

class CreditorUserModel {
  final String id;
  final String userCode;
  final String displayName;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? promptPayId;
  final String? promptPayIdType;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankCode;
  final String? truemoneyPhone;

  const CreditorUserModel({
    required this.id,
    required this.userCode,
    required this.displayName,
    this.fullName,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.promptPayId,
    this.promptPayIdType,
    this.bankAccountNumber,
    this.bankName,
    this.bankCode,
    this.truemoneyPhone,
  });

  factory CreditorUserModel.fromJson(Map<String, dynamic> json) {
    return CreditorUserModel(
      id: json['id'] as String? ?? '',
      userCode: json['userCode'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'เจ้าของบิล',
      fullName: json['fullName'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      promptPayId: json['promptPayId'] as String?,
      promptPayIdType: json['promptPayIdType'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankName: json['bankName'] as String?,
      bankCode: json['bankCode'] as String?,
      truemoneyPhone: json['truemoneyPhone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userCode': userCode,
    'displayName': displayName,
    'fullName': fullName,
    'firstName': firstName,
    'lastName': lastName,
    'avatarUrl': avatarUrl,
    'promptPayId': promptPayId,
    'promptPayIdType': promptPayIdType,
    'bankAccountNumber': bankAccountNumber,
    'bankName': bankName,
    'bankCode': bankCode,
    'truemoneyPhone': truemoneyPhone,
  };
}

class DebtItemModel {
  final String id; // bill_items.id
  final String billId;
  final String debtorId;
  final String billTitle;
  final String currency;
  final double originalAmount;
  final double currentAmount;
  final double amountPaid;
  final double amountWrittenOff;
  final double outstandingAmount;
  final String status; // unpaid, partially_paid, paid, written_off
  final bool isAcknowledged;
  final DateTime? acknowledgedAt;
  final bool isLocked;
  final bool isOutstanding;
  final DateTime debtStartDate;
  final CreditorUserModel creditor;
  final String? receiptImageUrl;
  final int paymentsCount;
  final String? latestPaymentStatus;

  const DebtItemModel({
    required this.id,
    required this.billId,
    required this.debtorId,
    required this.billTitle,
    this.currency = 'THB',
    required this.originalAmount,
    required this.currentAmount,
    this.amountPaid = 0.0,
    this.amountWrittenOff = 0.0,
    required this.outstandingAmount,
    required this.status,
    this.isAcknowledged = false,
    this.acknowledgedAt,
    this.isLocked = false,
    this.isOutstanding = true,
    required this.debtStartDate,
    required this.creditor,
    this.receiptImageUrl,
    this.paymentsCount = 0,
    this.latestPaymentStatus,
  });

  /// Invariant: currentAmount = amountPaid + amountWrittenOff + outstandingAmount
  bool get hasRemainingDebt => outstandingAmount > 0;
  bool get isPartiallyPaid => amountPaid > 0 && outstandingAmount > 0;
  double get paymentProgress =>
      currentAmount > 0 ? (amountPaid / currentAmount).clamp(0.0, 1.0) : 0.0;

  factory DebtItemModel.fromJson(Map<String, dynamic> json) {
    return DebtItemModel(
      id: json['id'] as String? ?? '',
      billId: json['billId'] as String? ?? '',
      debtorId: json['debtorId'] as String? ?? '',
      billTitle: json['billTitle'] as String? ?? 'บิลค่าใช้จ่าย',
      currency: json['currency'] as String? ?? 'THB',
      originalAmount: _asDouble(json['originalAmount']),
      currentAmount: _asDouble(json['currentAmount']),
      amountPaid: _asDouble(json['amountPaid']),
      amountWrittenOff: _asDouble(json['amountWrittenOff']),
      outstandingAmount: _asDouble(json['outstandingAmount']),
      status: json['status'] as String? ?? 'unpaid',
      isAcknowledged: _asBool(json['isAcknowledged'] ?? json['is_acknowledged']),
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString())
          : null,
      isLocked: _asBool(json['isLocked'] ?? json['is_locked']),
      isOutstanding: _asBool(json['isOutstanding'] ?? json['is_outstanding'] ?? true),
      debtStartDate: json['debtStartDate'] != null
          ? DateTime.tryParse(json['debtStartDate'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      creditor: json['creditor'] != null
          ? CreditorUserModel.fromJson(json['creditor'] as Map<String, dynamic>)
          : const CreditorUserModel(
              id: '',
              userCode: '',
              displayName: 'เจ้าของบิล',
            ),
      receiptImageUrl: json['receiptImageUrl'] as String?,
      paymentsCount: _asInt(json['paymentsCount']),
      latestPaymentStatus: json['latestPaymentStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'billId': billId,
    'debtorId': debtorId,
    'billTitle': billTitle,
    'currency': currency,
    'originalAmount': originalAmount,
    'currentAmount': currentAmount,
    'amountPaid': amountPaid,
    'amountWrittenOff': amountWrittenOff,
    'outstandingAmount': outstandingAmount,
    'status': status,
    'isLocked': isLocked,
    'isOutstanding': isOutstanding,
    'debtStartDate': debtStartDate.toIso8601String(),
    'creditor': creditor.toJson(),
    'paymentsCount': paymentsCount,
    'latestPaymentStatus': latestPaymentStatus,
  };
}

class DebtSummaryModel {
  final int outstandingCount;
  final double totalOutstandingAmount;
  final String currency;

  const DebtSummaryModel({
    required this.outstandingCount,
    required this.totalOutstandingAmount,
    this.currency = 'THB',
  });

  factory DebtSummaryModel.fromJson(Map<String, dynamic> json) {
    return DebtSummaryModel(
      outstandingCount: _asInt(json['outstandingCount']),
      totalOutstandingAmount: _asDouble(json['totalOutstandingAmount']),
      currency: json['currency'] as String? ?? 'THB',
    );
  }

  Map<String, dynamic> toJson() => {
    'outstandingCount': outstandingCount,
    'totalOutstandingAmount': totalOutstandingAmount,
    'currency': currency,
  };
}

class UserDebtsResponseModel {
  final DebtSummaryModel summary;
  final List<DebtItemModel> debts;

  const UserDebtsResponseModel({required this.summary, required this.debts});

  factory UserDebtsResponseModel.fromJson(Map<String, dynamic> json) {
    final summaryData = json['summary'] as Map<String, dynamic>? ?? {};
    final debtsList = (json['debts'] as List?) ?? [];

    return UserDebtsResponseModel(
      summary: DebtSummaryModel.fromJson(summaryData),
      debts: debtsList
          .map((e) => DebtItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaymentInstallmentModel {
  final String id;
  final String billItemId;
  final String payerId;
  final double amount;
  final String currency;
  final String
  status; // pending_verification, pending_owner_confirmation, confirmed, rejected, verification_failed
  final int? installmentNumber;
  final String? slipImageUrl;
  final String? slipOkReferenceId;
  final DateTime? slipOkVerifiedAt;
  final DateTime? confirmedByOwnerAt;
  final String? rejectedReason;
  final DateTime createdAt;

  const PaymentInstallmentModel({
    required this.id,
    required this.billItemId,
    required this.payerId,
    required this.amount,
    this.currency = 'THB',
    required this.status,
    this.installmentNumber,
    this.slipImageUrl,
    this.slipOkReferenceId,
    this.slipOkVerifiedAt,
    this.confirmedByOwnerAt,
    this.rejectedReason,
    required this.createdAt,
  });

  factory PaymentInstallmentModel.fromJson(Map<String, dynamic> json) {
    return PaymentInstallmentModel(
      id: json['id'] as String? ?? '',
      billItemId:
          json['billItemId'] as String? ??
          json['participantId'] as String? ??
          '',
      payerId: json['payerId'] as String? ?? '',
      amount: _asDouble(json['amount']),
      currency: json['currency'] as String? ?? 'THB',
      status: json['status'] as String? ?? 'pending_verification',
      installmentNumber: _asOptionalInt(json['installmentNumber']),
      slipImageUrl: json['slipImageUrl'] as String?,
      slipOkReferenceId: json['slipOkReferenceId'] as String?,
      slipOkVerifiedAt: json['slipOkVerifiedAt'] != null
          ? DateTime.tryParse(json['slipOkVerifiedAt'].toString())
          : null,
      confirmedByOwnerAt: json['confirmedByOwnerAt'] != null
          ? DateTime.tryParse(json['confirmedByOwnerAt'].toString())
          : null,
      rejectedReason: json['rejectedReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'billItemId': billItemId,
    'payerId': payerId,
    'amount': amount,
    'currency': currency,
    'status': status,
    'installmentNumber': installmentNumber,
    'slipImageUrl': slipImageUrl,
    'slipOkReferenceId': slipOkReferenceId,
    'slipOkVerifiedAt': slipOkVerifiedAt?.toIso8601String(),
    'confirmedByOwnerAt': confirmedByOwnerAt?.toIso8601String(),
    'rejectedReason': rejectedReason,
    'createdAt': createdAt.toIso8601String(),
  };
}

class CreatePaymentResultModel {
  final String id;
  final String billId;
  final String participantId;
  final String payerId;
  final double amount;
  final String status;
  final int? installmentNumber;
  final bool slipOkVerified;
  final String message;

  const CreatePaymentResultModel({
    required this.id,
    required this.billId,
    required this.participantId,
    required this.payerId,
    required this.amount,
    required this.status,
    this.installmentNumber,
    required this.slipOkVerified,
    required this.message,
  });

  factory CreatePaymentResultModel.fromJson(Map<String, dynamic> json) {
    return CreatePaymentResultModel(
      id: json['id'] as String? ?? '',
      billId: json['billId'] as String? ?? '',
      participantId: json['participantId'] as String? ?? '',
      payerId: json['payerId'] as String? ?? '',
      amount: _asDouble(json['amount']),
      status: json['status'] as String? ?? 'pending_owner_confirmation',
      installmentNumber: _asOptionalInt(json['installmentNumber']),
      slipOkVerified: json['slipOkVerified'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

class ReceivableBillItemModel {
  final String id; // bill_items.id
  final String billId;
  final String billTitle;
  final String currency;
  final double originalAmount;
  final double currentAmount;
  final double amountPaid;
  final double amountWrittenOff;
  final double outstandingAmount;
  final String status;
  final bool isLocked;
  final bool isOutstanding;
  final DateTime debtStartDate;
  final String? receiptImageUrl;
  final int paymentsCount;
  final String? latestPaymentStatus;

  const ReceivableBillItemModel({
    required this.id,
    required this.billId,
    required this.billTitle,
    this.currency = 'THB',
    required this.originalAmount,
    required this.currentAmount,
    this.amountPaid = 0.0,
    this.amountWrittenOff = 0.0,
    required this.outstandingAmount,
    required this.status,
    this.isLocked = false,
    this.isOutstanding = true,
    required this.debtStartDate,
    this.receiptImageUrl,
    this.paymentsCount = 0,
    this.latestPaymentStatus,
  });

  bool get hasRemainingDebt => outstandingAmount > 0;
  bool get isPartiallyPaid => amountPaid > 0 && outstandingAmount > 0;
  double get paymentProgress =>
      currentAmount > 0 ? (amountPaid / currentAmount).clamp(0.0, 1.0) : 0.0;

  factory ReceivableBillItemModel.fromJson(Map<String, dynamic> json) {
    return ReceivableBillItemModel(
      id: json['id'] as String? ?? '',
      billId: json['billId'] as String? ?? '',
      billTitle: json['billTitle'] as String? ?? 'บิลค่าใช้จ่าย',
      currency: json['currency'] as String? ?? 'THB',
      originalAmount: _asDouble(json['originalAmount']),
      currentAmount: _asDouble(json['currentAmount']),
      amountPaid: _asDouble(json['amountPaid']),
      amountWrittenOff: _asDouble(json['amountWrittenOff']),
      outstandingAmount: _asDouble(json['outstandingAmount']),
      status: json['status'] as String? ?? 'unpaid',
      isLocked: json['isLocked'] as bool? ?? false,
      isOutstanding: json['isOutstanding'] as bool? ?? true,
      debtStartDate: json['debtStartDate'] != null
          ? DateTime.tryParse(json['debtStartDate'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      receiptImageUrl: json['receiptImageUrl'] as String?,
      paymentsCount: _asInt(json['paymentsCount']),
      latestPaymentStatus: json['latestPaymentStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'billId': billId,
    'billTitle': billTitle,
    'currency': currency,
    'originalAmount': originalAmount,
    'currentAmount': currentAmount,
    'amountPaid': amountPaid,
    'amountWrittenOff': amountWrittenOff,
    'outstandingAmount': outstandingAmount,
    'status': status,
    'isLocked': isLocked,
    'isOutstanding': isOutstanding,
    'debtStartDate': debtStartDate.toIso8601String(),
    'receiptImageUrl': receiptImageUrl,
    'paymentsCount': paymentsCount,
    'latestPaymentStatus': latestPaymentStatus,
  };
}

class DebtorUserModel {
  final String id;
  final String userCode;
  final String displayName;
  final String? avatarUrl;
  final String? promptPayId;
  final String? bankAccountNumber;

  const DebtorUserModel({
    required this.id,
    required this.userCode,
    required this.displayName,
    this.avatarUrl,
    this.promptPayId,
    this.bankAccountNumber,
  });

  factory DebtorUserModel.fromJson(Map<String, dynamic> json) {
    return DebtorUserModel(
      id: json['id'] as String? ?? '',
      userCode: json['userCode'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'เพื่อน',
      avatarUrl: json['avatarUrl'] as String?,
      promptPayId: json['promptPayId'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userCode': userCode,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'promptPayId': promptPayId,
    'bankAccountNumber': bankAccountNumber,
  };
}

class ReceivableFriendModel {
  final DebtorUserModel debtor;
  final int outstandingBillCount;
  final int totalBillsCount;
  final double totalOriginalAmount;
  final double totalCurrentAmount;
  final double totalAmountPaid;
  final double totalAmountWrittenOff;
  final double totalOutstandingAmount;
  final bool hasOutstandingDebt;
  final DateTime oldestDebtStartDate;
  final String? latestPaymentStatus;
  final List<ReceivableBillItemModel> bills;

  const ReceivableFriendModel({
    required this.debtor,
    required this.outstandingBillCount,
    required this.totalBillsCount,
    required this.totalOriginalAmount,
    required this.totalCurrentAmount,
    required this.totalAmountPaid,
    required this.totalAmountWrittenOff,
    required this.totalOutstandingAmount,
    required this.hasOutstandingDebt,
    required this.oldestDebtStartDate,
    this.latestPaymentStatus,
    required this.bills,
  });

  factory ReceivableFriendModel.fromJson(Map<String, dynamic> json) {
    final debtorData = json['debtor'] as Map<String, dynamic>? ?? {};
    final billsList = (json['bills'] as List?) ?? [];

    return ReceivableFriendModel(
      debtor: DebtorUserModel.fromJson(debtorData),
      outstandingBillCount: _asInt(json['outstandingBillCount']),
      totalBillsCount: _asInt(json['totalBillsCount']),
      totalOriginalAmount: _asDouble(json['totalOriginalAmount']),
      totalCurrentAmount: _asDouble(json['totalCurrentAmount']),
      totalAmountPaid: _asDouble(json['totalAmountPaid']),
      totalAmountWrittenOff: _asDouble(json['totalAmountWrittenOff']),
      totalOutstandingAmount: _asDouble(json['totalOutstandingAmount']),
      hasOutstandingDebt: json['hasOutstandingDebt'] as bool? ?? false,
      oldestDebtStartDate: json['oldestDebtStartDate'] != null
          ? DateTime.tryParse(json['oldestDebtStartDate'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      latestPaymentStatus: json['latestPaymentStatus'] as String?,
      bills: billsList
          .map(
            (e) => ReceivableBillItemModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ReceivableSummaryModel {
  final int debtorCount;
  final double totalOutstandingAmount;
  final double totalPaidAmount;
  final double totalWrittenOffAmount;
  final double totalOriginalAmount;
  final String currency;

  const ReceivableSummaryModel({
    required this.debtorCount,
    required this.totalOutstandingAmount,
    this.totalPaidAmount = 0.0,
    this.totalWrittenOffAmount = 0.0,
    this.totalOriginalAmount = 0.0,
    this.currency = 'THB',
  });

  factory ReceivableSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReceivableSummaryModel(
      debtorCount: _asInt(json['debtorCount']),
      totalOutstandingAmount: _asDouble(json['totalOutstandingAmount']),
      totalPaidAmount: _asDouble(json['totalPaidAmount']),
      totalWrittenOffAmount: _asDouble(json['totalWrittenOffAmount']),
      totalOriginalAmount: _asDouble(json['totalOriginalAmount']),
      currency: json['currency'] as String? ?? 'THB',
    );
  }

  Map<String, dynamic> toJson() => {
    'debtorCount': debtorCount,
    'totalOutstandingAmount': totalOutstandingAmount,
    'totalPaidAmount': totalPaidAmount,
    'totalWrittenOffAmount': totalWrittenOffAmount,
    'totalOriginalAmount': totalOriginalAmount,
    'currency': currency,
  };
}

class UserReceivablesResponseModel {
  final ReceivableSummaryModel summary;
  final List<ReceivableFriendModel> friends;

  const UserReceivablesResponseModel({
    required this.summary,
    required this.friends,
  });

  factory UserReceivablesResponseModel.fromJson(Map<String, dynamic> json) {
    final summaryData = json['summary'] as Map<String, dynamic>? ?? {};
    final friendsList = (json['friends'] as List?) ?? [];

    return UserReceivablesResponseModel(
      summary: ReceivableSummaryModel.fromJson(summaryData),
      friends: friendsList
          .map((e) => ReceivableFriendModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
