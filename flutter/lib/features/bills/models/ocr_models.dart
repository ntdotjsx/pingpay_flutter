class ReceiptItemModel {
  final String name;
  final double amount;
  final int quantity;

  const ReceiptItemModel({
    required this.name,
    required this.amount,
    this.quantity = 1,
  });

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

  factory ReceiptOcrResultModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List?) ?? [];
    return ReceiptOcrResultModel(
      merchant: json['merchant'] as String? ?? 'ร้านค้า (Receipt)',
      date: json['date'] as String?,
      items: itemsList
          .map((e) => ReceiptItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      serviceCharge: (json['serviceCharge'] is Map)
          ? (json['serviceCharge']['amount'] as num?)?.toDouble()
          : (json['serviceCharge'] as num?)?.toDouble(),
      vat: (json['vat'] is Map)
          ? (json['vat']['amount'] as num?)?.toDouble()
          : (json['vat'] as num?)?.toDouble(),
      discount: (json['discount'] as num?)?.toDouble(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'THB',
      formulaExplanation: json['formulaExplanation'] as String?,
      rawText: json['rawText'] as String?,
    );
  }
}
