class ReceiptItemModel {
  final String name;
  final double amount;
  final int quantity;

  const ReceiptItemModel({
    required this.name,
    required this.amount,
    this.quantity = 1,
  });

  ReceiptItemModel copyWith({String? name, double? amount, int? quantity}) {
    return ReceiptItemModel(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
    );
  }

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptItemModel(
      name: json['name'] as String? ?? 'รายการสินค้า',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'quantity': quantity,
  };
}

class ReceiptOcrResultModel {
  final String merchant;
  final String? date;
  final List<ReceiptItemModel> items;
  final double? subtotal;
  final double? serviceCharge;
  final double? vat;
  final double? discount;
  final double totalAmount;
  final String currency;
  final String? formulaExplanation;
  final String? rawText;

  const ReceiptOcrResultModel({
    required this.merchant,
    this.date,
    required this.items,
    this.subtotal,
    this.serviceCharge,
    this.vat,
    this.discount,
    required this.totalAmount,
    this.currency = 'THB',
    this.formulaExplanation,
    this.rawText,
  });

  ReceiptOcrResultModel copyWith({
    String? merchant,
    String? date,
    List<ReceiptItemModel>? items,
    double? subtotal,
    double? serviceCharge,
    double? vat,
    double? discount,
    double? totalAmount,
    String? currency,
    String? formulaExplanation,
    String? rawText,
  }) {
    return ReceiptOcrResultModel(
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      vat: vat ?? this.vat,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      formulaExplanation: formulaExplanation ?? this.formulaExplanation,
      rawText: rawText ?? this.rawText,
    );
  }

  static bool _isSummaryOrTotalLine(
    String name,
    double amount,
    double totalAmount,
  ) {
    final lower = name.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    // Check Thai / English summary keywords
    const keywords = [
      'รวม',
      'ยอดรวม',
      'ทั้งสิ้น',
      'รวมทั้งสิ้น',
      'รวมเป็นเงิน',
      'จำนวนเงิน',
      'หักจำนวนเงิน',
      'ชำระ',
      'เงินสด',
      'เงินทอน',
      'total',
      'grandtotal',
      'subtotal',
      'nettotal',
      'amountdue',
      'cash',
      'change',
      'vat',
      'tax',
      'servicecharge',
      'charge',
    ];

    for (final kw in keywords) {
      if (lower.contains(kw)) {
        return true;
      }
    }

    // Heuristic: If item amount equals the exact total and name contains typical receipt footer OCR noise
    if ((amount - totalAmount).abs() < 0.01 &&
        (lower.contains('ทง') ||
            lower.contains('หคด') ||
            lower.contains('เงง') ||
            lower.contains('บาท') ||
            lower.contains('thb'))) {
      return true;
    }

    return false;
  }

  factory ReceiptOcrResultModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List?) ?? [];
    final total = (json['totalAmount'] as num?)?.toDouble() ?? 0.0;

    final parsedItems = itemsList
        .map((e) => ReceiptItemModel.fromJson(e as Map<String, dynamic>))
        .where((item) => !_isSummaryOrTotalLine(item.name, item.amount, total))
        .toList();

    return ReceiptOcrResultModel(
      merchant: json['merchant'] as String? ?? 'ร้านค้า (Receipt)',
      date: json['date'] as String?,
      items: parsedItems,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      serviceCharge: (json['serviceCharge'] is Map)
          ? (json['serviceCharge']['amount'] as num?)?.toDouble()
          : (json['serviceCharge'] as num?)?.toDouble(),
      vat: (json['vat'] is Map)
          ? (json['vat']['amount'] as num?)?.toDouble()
          : (json['vat'] as num?)?.toDouble(),
      discount: (json['discount'] as num?)?.toDouble(),
      totalAmount: total,
      currency: json['currency'] as String? ?? 'THB',
      formulaExplanation: json['formulaExplanation'] as String?,
      rawText: json['rawText'] as String?,
    );
  }
}
