class InputValidators {
  /// Validates Thai mobile phone number (10 digits, starts with 06, 08, 09, etc.)
  static String? validatePhoneNumber(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      if (required) return 'กรุณากรอกเบอร์โทรศัพท์';
      return null;
    }
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length != 10) {
      return 'เบอร์โทรศัพท์ต้องมี 10 หลัก (ปัจจุบันมี ${clean.length} หลัก)';
    }
    if (!clean.startsWith('0')) {
      return 'เบอร์โทรศัพท์ต้องขึ้นต้นด้วย 0';
    }
    return null;
  }

  /// Validates Thai National ID (13 digits with checksum calculation)
  static String? validateNationalId(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      if (required) return 'กรุณากรอกเลขบัตรประชาชน';
      return null;
    }
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length != 13) {
      return 'เลขบัตรประชาชนต้องมี 13 หลัก (ปัจจุบันมี ${clean.length} หลัก)';
    }

    // Checksum verification
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(clean[i]) * (13 - i);
    }
    final checkDigit = (11 - (sum % 11)) % 10;
    if (int.parse(clean[12]) != checkDigit) {
      return 'เลขบัตรประชาชนไม่ถูกต้องตามหลักการคำนวณ';
    }

    return null;
  }

  /// Validates PromptPay ID (either 10-digit phone, 13-digit National ID, or 15-digit e-Wallet)
  static String? validatePromptPay(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      if (required) return 'กรุณาระบุเบอร์พร้อมเพย์หรือเลขบัตรประชาชน';
      return null;
    }
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) {
      if (!clean.startsWith('0')) {
        return 'เบอร์พร้อมเพย์ 10 หลักต้องขึ้นต้นด้วย 0';
      }
      return null;
    } else if (clean.length == 13) {
      return validateNationalId(clean, required: true);
    } else if (clean.length == 15) {
      return null; // e-Wallet ID
    } else {
      return 'พร้อมเพย์ต้องเป็นเบอร์โทร (10 หลัก) หรือเลขบัตร ปชช. (13 หลัก)';
    }
  }

  /// Validates Thai Bank Account Number (10 to 12 digits)
  static String? validateBankAccount(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      if (required) return 'กรุณากรอกเลขบัญชีธนาคาร';
      return null;
    }
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length < 10 || clean.length > 12) {
      return 'เลขบัญชีธนาคารต้องมี 10 - 12 หลัก (ปัจจุบันมี ${clean.length} หลัก)';
    }
    return null;
  }

  /// Validates Financial Amount / Number
  static String? validateAmount(
    String? value, {
    bool required = true,
    double? min,
    double? max,
    String? fieldName,
  }) {
    final name = fieldName ?? 'จำนวนเงิน';
    if (value == null || value.trim().isEmpty) {
      if (required) return 'กรุณากรอก$name';
      return null;
    }
    final clean = value.replaceAll(',', '').trim();
    final amount = double.tryParse(clean);
    if (amount == null) {
      return 'กรุณากรอกตัวเลขที่ถูกต้อง';
    }
    if (min != null && amount < min) {
      return '$nameต้องไม่น้อยกว่า ฿${min.toStringAsFixed(2)}';
    }
    if (max != null && amount > max) {
      return '$nameต้องไม่เกิน ฿${max.toStringAsFixed(2)}';
    }
    if (amount <= 0 && min == null) {
      return '$nameต้องมากกว่า 0';
    }
    return null;
  }

  /// Validates Real First & Last Name for EasySlip receiver bank verification
  static String? validateRealName(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      if (required) return 'กรุณากรอกชื่อและนามสกุลจริง';
      return null;
    }
    final trimmed = value.trim();

    // Check for illegal characters (numbers, special symbols)
    if (RegExp(r'[0-9!@#$%^&*()_+={}\[\]:;"<>,.?/\\|~`]').hasMatch(trimmed)) {
      return 'ชื่อและนามสกุลต้องประกอบด้วยตัวอักษรเท่านั้น (ไม่มีตัวเลขหรือสัญลักษณ์)';
    }

    // Split words by spaces
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) {
      return 'กรุณากรอกทั้งชื่อและนามสกุล (เว้นวรรคระหว่างชื่อกับนามสกุล)';
    }

    if (words[0].length < 2 || words[1].length < 2) {
      return 'ชื่อและนามสกุลต้องมีความยาวอย่างน้อย 2 ตัวอักษร';
    }

    return null;
  }

  /// Validates required text (with min/max length)
  static String? validateRequired(
    String? value, {
    required String fieldName,
    int minLength = 1,
    int? maxLength,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอก$fieldName';
    }
    final trimmed = value.trim();
    if (trimmed.length < minLength) {
      return '$fieldNameต้องมีความยาวอย่างน้อย $minLength ตัวอักษร';
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return '$fieldNameต้องมีความยาวไม่เกิน $maxLength ตัวอักษร';
    }
    return null;
  }
}

