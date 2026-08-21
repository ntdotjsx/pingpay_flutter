import 'package:flutter/foundation.dart';

@immutable
class BillSplitParticipant {
  final String userId;
  final String displayName;
  final String userCode;
  final String? avatarUrl;
  final int
  amountSatang; // Stored in minor units (satang) to avoid floating point errors
  final bool isManuallyAdjusted;

  const BillSplitParticipant({
    required this.userId,
    required this.displayName,
    required this.userCode,
    this.avatarUrl,
    required this.amountSatang,
    this.isManuallyAdjusted = false,
  });

  double get amountBaht => amountSatang / 100.0;

  BillSplitParticipant copyWith({
    String? userId,
    String? displayName,
    String? userCode,
    String? avatarUrl,
    int? amountSatang,
    bool? isManuallyAdjusted,
  }) {
    return BillSplitParticipant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      userCode: userCode ?? this.userCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      amountSatang: amountSatang ?? this.amountSatang,
      isManuallyAdjusted: isManuallyAdjusted ?? this.isManuallyAdjusted,
    );
  }
}

class BillSplitCalculator {
  /// Converts Baht to integer satang minor units.
  static int toSatang(double baht) => (baht * 100).round();

  /// Converts Satang to Baht floating units.
  static double toBaht(int satang) => satang / 100.0;

  /// Distributes total satang evenly among participants.
  /// Any remainder satang is deterministically distributed to the first [remainder] participants.
  static List<int> allocateEvenlySatang(int totalSatang, int count) {
    if (count <= 0) return [];
    final baseSatang = totalSatang ~/ count;
    final remainder = totalSatang % count;

    final result = List<int>.filled(count, baseSatang);
    for (int i = 0; i < remainder; i++) {
      result[i] += 1;
    }
    return result;
  }

  /// Calculates default split including or excluding the owner/creator.
  /// If [includeOwner] is true:
  /// Total satang is divided among (participants.length + 1).
  /// Owner gets 1 share (or [customOwnerSatang] if manually adjusted).
  /// Participants get the remaining satang split evenly among them.
  static ({int ownerSatang, List<BillSplitParticipant> participants})
  calculateSplitWithOptions({
    required List<BillSplitParticipant> participants,
    required int totalSatang,
    required bool includeOwner,
    int? customOwnerSatang,
  }) {
    if (participants.isEmpty) {
      final ownerAmt = includeOwner ? totalSatang : 0;
      return (ownerSatang: ownerAmt, participants: <BillSplitParticipant>[]);
    }

    if (!includeOwner) {
      final amounts = allocateEvenlySatang(totalSatang, participants.length);
      final updated = [
        for (int i = 0; i < participants.length; i++)
          participants[i].copyWith(
            amountSatang: amounts[i],
            isManuallyAdjusted: false,
          ),
      ];
      return (ownerSatang: 0, participants: updated);
    }

    // Include owner in split
    int effectiveOwnerSatang;
    if (customOwnerSatang != null) {
      effectiveOwnerSatang = customOwnerSatang.clamp(0, totalSatang);
    } else {
      // Default: 1 share out of (participants.length + 1)
      final totalShares = participants.length + 1;
      final shares = allocateEvenlySatang(totalSatang, totalShares);
      effectiveOwnerSatang = shares[0];
    }

    final remainingSatang = (totalSatang - effectiveOwnerSatang).clamp(
      0,
      totalSatang,
    );
    final otherAmounts = allocateEvenlySatang(
      remainingSatang,
      participants.length,
    );

    final updated = [
      for (int i = 0; i < participants.length; i++)
        participants[i].copyWith(
          amountSatang: otherAmounts[i],
          isManuallyAdjusted: false,
        ),
    ];

    return (ownerSatang: effectiveOwnerSatang, participants: updated);
  }

  /// Recalculates split when a specific participant's amount is edited.
  /// Invariant: SUM(all participant amountSatang) + ownerSatang == totalSatang.
  static List<BillSplitParticipant> adjustParticipantAmount({
    required List<BillSplitParticipant> participants,
    required int totalSatang,
    required int targetIndex,
    required int newAmountSatang,
    int ownerSatang = 0,
  }) {
    if (participants.isEmpty) {
      return [];
    }
    if (targetIndex < 0 || targetIndex >= participants.length) {
      return participants;
    }

    final poolSatang = (totalSatang - ownerSatang).clamp(0, totalSatang);
    final clampedNewAmount = newAmountSatang.clamp(0, poolSatang);
    final otherIndices = [
      for (int i = 0; i < participants.length; i++)
        if (i != targetIndex) i,
    ];

    if (otherIndices.isEmpty) {
      return [
        participants[0].copyWith(
          amountSatang: poolSatang,
          isManuallyAdjusted: true,
        ),
      ];
    }

    final remainingSatang = poolSatang - clampedNewAmount;
    final otherAllocations = allocateEvenlySatang(
      remainingSatang,
      otherIndices.length,
    );

    final updated = List<BillSplitParticipant>.from(participants);
    updated[targetIndex] = updated[targetIndex].copyWith(
      amountSatang: clampedNewAmount,
      isManuallyAdjusted: true,
    );

    for (int j = 0; j < otherIndices.length; j++) {
      final idx = otherIndices[j];
      updated[idx] = updated[idx].copyWith(
        amountSatang: otherAllocations[j],
        isManuallyAdjusted: false,
      );
    }

    return updated;
  }

  /// Initializes or resets participant amounts evenly.
  static List<BillSplitParticipant> initializeEvenSplit({
    required List<BillSplitParticipant> participants,
    required int totalSatang,
    int ownerSatang = 0,
  }) {
    if (participants.isEmpty) return [];
    final pool = (totalSatang - ownerSatang).clamp(0, totalSatang);
    final amounts = allocateEvenlySatang(pool, participants.length);

    return [
      for (int i = 0; i < participants.length; i++)
        participants[i].copyWith(
          amountSatang: amounts[i],
          isManuallyAdjusted: false,
        ),
    ];
  }

  /// Verifies exact invariant equality: SUM(participant amounts) + ownerSatang == totalSatang.
  static bool validateTotalInvariant(
    List<BillSplitParticipant> participants,
    int totalSatang, {
    int ownerSatang = 0,
  }) {
    final sum =
        participants.fold<int>(0, (acc, curr) => acc + curr.amountSatang) +
        ownerSatang;
    return sum == totalSatang;
  }
}
