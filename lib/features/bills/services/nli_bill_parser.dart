import '../../friends/models/friend_models.dart';
import '../models/nli_bill_result_model.dart';
import '../models/ocr_models.dart';

/// Intelligent Thai Natural Language Parser for pingpay bill creation
class NliBillParser {
  /// Parse Thai natural language prompt against user friends and custom nicknames
  static NliParsedBill parse(
    String rawText,
    List<FriendUserModel> userFriends, {
    Map<String, String> friendNicknames = const {},
  }) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return NliParsedBill(
        title: '',
        totalAmount: 0.0,
        items: const [],
        matchedParticipants: const [],
        includeOwner: true,
        rawPrompt: text,
      );
    }

    // 1. Detect Owner Inclusion / Exclusion
    bool includeOwner = true;
    final lowerText = text.toLowerCase();
    if (lowerText.contains('ไม่รวมฉัน') ||
        lowerText.contains('ไม่คิดส่วนฉัน') ||
        lowerText.contains('ไม่หารฉัน') ||
        lowerText.contains('ตัดส่วนฉัน') ||
        lowerText.contains('ออกให้เพื่อน') ||
        lowerText.contains('จ่ายให้เพื่อนหมด')) {
      includeOwner = false;
    } else if (lowerText.contains('รวมฉัน') ||
        lowerText.contains('มีส่วนฉัน') ||
        lowerText.contains('หารฉันด้วย') ||
        lowerText.contains('ฉันด้วย')) {
      includeOwner = true;
    }

    // 2. Detect Explicit Person Count (e.g. "หาร 4 คน", "แชร์ 3 คน")
    int? explicitPersonCount;
    final personCountRegex = RegExp(r'(?:หาร|แชร์|แบ่ง)\s*(?:กัน)?\s*(\d+)\s*(?:คน|ที่)');
    final countMatch = personCountRegex.firstMatch(text);
    if (countMatch != null) {
      explicitPersonCount = int.tryParse(countMatch.group(1) ?? '');
    }

    // 3. Extract Total Amount
    double totalAmount = 0.0;
    final totalAmountRegex = RegExp(
      r'(?:ยอด|รวม|ราคา|ทั้งหมด)?\s*(?:฿\s*)?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(?:บาท|บ\.|฿|\.-|\.-)?',
      caseSensitive: false,
    );

    final totalMatches = totalAmountRegex.allMatches(text).toList();
    for (final m in totalMatches) {
      final numStr = m.group(1)?.replaceAll(',', '') ?? '';
      final parsed = double.tryParse(numStr);
      if (parsed != null && parsed > 0) {
        if (parsed != explicitPersonCount?.toDouble()) {
          if (parsed > totalAmount) {
            totalAmount = parsed;
          }
        }
      }
    }

    // 4. Friend Matching & Custom Amounts Extraction
    final matchedParticipants = <NliParticipant>[];
    final matchedFriendKeys = <String>{};
    final unmatchedNames = <String>[];

    // Helper to get effective display name for a friend
    String getEffectiveName(FriendUserModel friend) {
      if (friend.id != null && friendNicknames.containsKey(friend.id!)) {
        final nick = friendNicknames[friend.id!];
        if (nick != null && nick.trim().isNotEmpty) return nick.trim();
      }
      if (friendNicknames.containsKey(friend.userCode)) {
        final nick = friendNicknames[friend.userCode];
        if (nick != null && nick.trim().isNotEmpty) return nick.trim();
      }
      return friend.displayName;
    }

    // Check for custom per-person amounts e.g. "บาส 80 เอ็ม 160"
    final customAmountPattern = RegExp(
      r'([a-zA-Zก-๙0-9_]+)\s*[:=]?\s*([0-9]+(?:\.[0-9]{1,2})?)\s*(?:บาท|บ\.|฿)?',
    );

    final customMatches = customAmountPattern.allMatches(text).toList();
    final potentialCustomNames = <String, double>{};

    for (final cm in customMatches) {
      final namePart = cm.group(1)?.trim() ?? '';
      final amtPart = double.tryParse(cm.group(2) ?? '');

      if (amtPart != null &&
          namePart != 'หาร' &&
          namePart != 'แชร์' &&
          namePart != 'รวม' &&
          namePart != 'ราคา' &&
          namePart != 'ยอด' &&
          namePart != 'คน' &&
          namePart != 'ละ' &&
          amtPart != totalAmount) {
        potentialCustomNames[namePart] = amtPart;
      }
    }

    // Match potential custom names against friend list and custom nicknames
    for (final entry in potentialCustomNames.entries) {
      final friend = _findMatchingFriend(entry.key, userFriends, friendNicknames);
      if (friend != null) {
        final key = friend.id ?? friend.userCode;
        if (!matchedFriendKeys.contains(key)) {
          matchedParticipants.add(
            NliParticipant(
              friend: friend,
              effectiveDisplayName: getEffectiveName(friend),
              customAmount: entry.value,
              isCustomAmountSpecified: true,
            ),
          );
          matchedFriendKeys.add(key);
        }
      }
    }

    // If no custom amounts or more friends mentioned, search general friends in text
    final friendsSectionRegex = RegExp(
      r'(?:หารกับ|กับ|ให้|แชร์กับ|แชร์ให้|ร่วมกับ|มี)\s+([^0-9]+?)(?:\s*(?:รวม|ยอด|ราคา|ทั้งหมด|\d+|ไม่รวมฉัน|มีส่วนฉัน|$))',
      caseSensitive: false,
    );

    final friendsSectionMatch = friendsSectionRegex.firstMatch(text);
    String searchZone = text;
    if (friendsSectionMatch != null) {
      searchZone = friendsSectionMatch.group(1) ?? text;
    }

    final tokenCandidates = searchZone
        .split(RegExp(r'[,+\s]+|และ|กับ'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length >= 2)
        .toList();

    for (final token in tokenCandidates) {
      if (_isStopWord(token)) continue;

      final friend = _findMatchingFriend(token, userFriends, friendNicknames);
      if (friend != null) {
        final key = friend.id ?? friend.userCode;
        if (!matchedFriendKeys.contains(key)) {
          matchedParticipants.add(
            NliParticipant(
              friend: friend,
              effectiveDisplayName: getEffectiveName(friend),
              isCustomAmountSpecified: false,
            ),
          );
          matchedFriendKeys.add(key);
        }
      } else {
        if (!_isCommonThaiWord(token) && !unmatchedNames.contains(token)) {
          unmatchedNames.add(token);
        }
      }
    }

    // Check all friends in the list to see if any display name or nickname is contained in the text directly
    for (final friend in userFriends) {
      final key = friend.id ?? friend.userCode;
      if (matchedFriendKeys.contains(key)) continue;

      final name = friend.displayName.trim().toLowerCase();
      final nick = (friendNicknames[friend.id ?? ''] ?? friendNicknames[friend.userCode] ?? '')
          .trim()
          .toLowerCase();

      if (nick.isNotEmpty && lowerText.contains(nick)) {
        matchedParticipants.add(
          NliParticipant(
            friend: friend,
            effectiveDisplayName: getEffectiveName(friend),
          ),
        );
        matchedFriendKeys.add(key);
        unmatchedNames.removeWhere((u) => u.toLowerCase() == nick);
      } else if (name.isNotEmpty && lowerText.contains(name)) {
        matchedParticipants.add(
          NliParticipant(
            friend: friend,
            effectiveDisplayName: getEffectiveName(friend),
          ),
        );
        matchedFriendKeys.add(key);
        unmatchedNames.removeWhere((u) => u.toLowerCase() == name);
      }
    }

    // 5. Extract Line Items (รายการสินค้า)
    final extractedItems = _extractLineItems(
      text,
      totalAmount,
      matchedParticipants,
      friendNicknames,
    );

    // If extracted sub-items sum up to a positive number and totalAmount wasn't explicitly given
    if (extractedItems.isNotEmpty) {
      final itemsSum = extractedItems.fold<double>(0.0, (acc, it) => acc + it.amount);
      if (totalAmount <= 0 || itemsSum == totalAmount) {
        totalAmount = itemsSum;
      }
    }

    // 6. Extract Bill Title
    String title = _extractBillTitle(
      text,
      totalAmount,
      matchedParticipants,
      extractedItems,
      friendNicknames,
    );

    // If no line items extracted, create a single item representing the whole bill
    final finalItems = extractedItems.isNotEmpty
        ? extractedItems
        : (totalAmount > 0
            ? [ReceiptItemModel(name: title, amount: totalAmount, quantity: 1)]
            : <ReceiptItemModel>[]);

    return NliParsedBill(
      title: title,
      totalAmount: totalAmount,
      items: finalItems,
      matchedParticipants: matchedParticipants,
      unmatchedNames: unmatchedNames,
      includeOwner: includeOwner,
      explicitPersonCount: explicitPersonCount,
      rawPrompt: text,
    );
  }

  /// Match a single name token with friend list & custom nicknames
  static FriendUserModel? _findMatchingFriend(
    String nameToken,
    List<FriendUserModel> friends,
    Map<String, String> friendNicknames,
  ) {
    final clean = nameToken.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // 1. Check custom nicknames map first
    for (final f in friends) {
      final customNick = (friendNicknames[f.id ?? ''] ?? friendNicknames[f.userCode] ?? '')
          .trim()
          .toLowerCase();
      if (customNick.isNotEmpty) {
        if (customNick == clean || customNick.startsWith(clean) || clean.startsWith(customNick)) {
          return f;
        }
      }
    }

    // 2. Exact match on displayName
    for (final f in friends) {
      if (f.displayName.trim().toLowerCase() == clean) return f;
    }

    // 3. Substring / Prefix match on displayName
    for (final f in friends) {
      final d = f.displayName.trim().toLowerCase();
      if (d.startsWith(clean) || clean.startsWith(d)) return f;
    }

    return null;
  }

  /// Extract product / food line items from natural language text
  static List<ReceiptItemModel> _extractLineItems(
    String text,
    double totalAmount,
    List<NliParticipant> participants,
    Map<String, String> nicknames,
  ) {
    final items = <ReceiptItemModel>[];
    final participantNames = <String>{};

    for (final p in participants) {
      participantNames.add(p.friend.displayName.trim().toLowerCase());
      participantNames.add(p.effectiveDisplayName.trim().toLowerCase());
    }

    for (final nick in nicknames.values) {
      if (nick.trim().isNotEmpty) {
        participantNames.add(nick.trim().toLowerCase());
      }
    }

    // Match patterns like: "เนื้อ 500", "ผัก 200", "น้ำ 100", "ลาเต้ 80", "หมู 300 บาท"
    final itemPattern = RegExp(
      r'([a-zA-Zก-๙0-9_]+)\s*[:=]?\s*([0-9]+(?:\.[0-9]{1,2})?)\s*(?:บาท|บ\.|฿)?',
    );

    final matches = itemPattern.allMatches(text);
    for (final m in matches) {
      var itemName = m.group(1)?.trim() ?? '';
      final itemPrice = double.tryParse(m.group(2) ?? '');

      if (itemPrice == null || itemPrice <= 0) continue;
      if (itemPrice == totalAmount && matches.length > 1) continue; // Skip total amount

      // Strip leading Thai prefixes like 'มี', 'สั่ง'
      itemName = itemName.replaceAll(RegExp(r'^(?:มี|สั่ง)\s*'), '').trim();

      final lowerName = itemName.toLowerCase();
      // Skip participant names, person count, and common stop words
      if (participantNames.contains(lowerName)) continue;
      if (_isStopWord(lowerName)) continue;
      if (lowerName == 'คน' || lowerName == 'ที่' || lowerName == 'หาร' || lowerName == 'รวม') continue;

      items.add(
        ReceiptItemModel(
          name: itemName,
          amount: itemPrice,
          quantity: 1,
        ),
      );
    }

    return items;
  }

  /// Extract a meaningful bill title from the prompt
  static String _extractBillTitle(
    String fullText,
    double totalAmount,
    List<NliParticipant> participants,
    List<ReceiptItemModel> items,
    Map<String, String> nicknames,
  ) {
    var cleaned = fullText;

    // Remove numbers and currency keywords
    cleaned = cleaned.replaceAll(RegExp(r'[0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?'), '');
    cleaned = cleaned.replaceAll(RegExp(r'(?:บาท|บ\.|฿|\.-|\.-)'), '');

    // Collect all friend names & nicknames to remove, sorted by descending length
    final namesToRemove = <String>{};
    for (final p in participants) {
      namesToRemove.add(p.friend.displayName.trim());
      namesToRemove.add(p.effectiveDisplayName.trim());
    }
    for (final nick in nicknames.values) {
      if (nick.trim().isNotEmpty) {
        namesToRemove.add(nick.trim());
      }
    }

    final sortedNames = namesToRemove.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final name in sortedNames) {
      if (name.isNotEmpty) {
        cleaned = cleaned.replaceAll(name, ' ');
      }
    }

    // Remove common splitting triggers
    cleaned = cleaned.replaceAll(
      RegExp(r'(?:หารกับ|แชร์กับ|หารกัน|หาร|แชร์|แบ่ง|รวมฉัน|ไม่รวมฉัน|ไม่คิดส่วนฉัน|มีส่วนฉัน|คนละ|เท่ากัน|คน|ที่|และ|กับ|สั่ง|มี|รายการ)'),
      ' ',
    );

    // Remove extracted items names from title if multiple items exist
    if (items.length > 1) {
      for (final item in items) {
        if (item.name.trim().isNotEmpty) {
          cleaned = cleaned.replaceAll(item.name.trim(), ' ');
        }
      }
    }

    // Clean whitespace and punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[,:;+\-=_]+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isNotEmpty && cleaned.length >= 2) {
      return cleaned;
    }

    if (items.isNotEmpty) {
      return items.first.name;
    }

    return 'บิลค่าใช้จ่าย';
  }

  static bool _isStopWord(String word) {
    const stopWords = {
      'หาร', 'แชร์', 'แบ่ง', 'กับ', 'และ', 'มี', 'ให้', 'คน', 'ละ',
      'คนละ', 'บาท', 'บ.', '฿', 'ยอด', 'รวม', 'ราคา', 'ทั้งหมด',
      'ไม่รวม', 'ไม่คิด', 'ฉัน', 'เรา', 'เพื่อน', 'ค่า', 'มื้อ',
      'วันนี้', 'เมื่อวาน', 'บิล', 'รายการ', 'กิน', 'จ่าย', 'สั่ง',
    };
    return stopWords.contains(word.trim().toLowerCase());
  }

  static bool _isCommonThaiWord(String word) {
    const common = {
      'ข้าว', 'น้ำ', 'ขนม', 'ชาบู', 'หมูกระทะ', 'กาแฟ', 'บุฟเฟต์',
      'แท็กซี่', 'รถ', 'น้ำมัน', 'ห้อง', 'โรงแรม', 'ทริป', 'ตั๋ว',
      'ส้มตำ', 'พิซซ่า', 'เบียร์', 'เหล้า', 'ค่าไฟ', 'ค่าน้ำ', 'ค่าเน็ต',
    };
    return common.contains(word.trim().toLowerCase());
  }
}
