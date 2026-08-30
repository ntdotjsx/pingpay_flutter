import '../../friends/models/friend_models.dart';
import 'ocr_models.dart';

/// Represents a participant extracted from Natural Language text
class NliParticipant {
  final FriendUserModel friend;
  final String effectiveDisplayName;
  final double? customAmount; // null if even split
  final bool isCustomAmountSpecified;

  const NliParticipant({
    required this.friend,
    required this.effectiveDisplayName,
    this.customAmount,
    this.isCustomAmountSpecified = false,
  });
}

/// Represents the parsed result from Natural Language Input (NLI)
class NliParsedBill {
  final String title;
  final double totalAmount;
  final List<ReceiptItemModel> items; // Extracted product line items
  final List<NliParticipant> matchedParticipants;
  final List<String> unmatchedNames;
  final bool includeOwner; // Whether the bill creator is included in the split
  final int? explicitPersonCount; // e.g. "หาร 4 คน"
  final String rawPrompt;

  const NliParsedBill({
    required this.title,
    required this.totalAmount,
    this.items = const [],
    required this.matchedParticipants,
    this.unmatchedNames = const [],
    this.includeOwner = true,
    this.explicitPersonCount,
    required this.rawPrompt,
  });

  bool get hasValidData => totalAmount > 0 || matchedParticipants.isNotEmpty || title.isNotEmpty || items.isNotEmpty;

  /// Total number of people involved in the split (participants + owner if included)
  int get totalPeopleCount {
    if (explicitPersonCount != null && explicitPersonCount! > 0) {
      return explicitPersonCount!;
    }
    final count = matchedParticipants.length + (includeOwner ? 1 : 0);
    return count > 0 ? count : 1;
  }

  /// Calculates individual share if even split
  double get estimatedPerPersonShare {
    if (totalAmount <= 0) return 0.0;
    return totalAmount / totalPeopleCount;
  }
}
