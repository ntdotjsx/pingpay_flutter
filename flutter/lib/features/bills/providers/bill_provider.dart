import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_models.dart';
import '../models/ocr_models.dart';
import '../repositories/bill_repository.dart';
import '../services/bill_split_calculator.dart';
import '../../friends/models/friend_models.dart';

enum BillCreationStateStatus {
  initial,
  extractingOcr,
  ready,
  submitting,
  success,
  error,
}

class BillCreationState {
  final BillCreationStateStatus status;
  final String title;
  final String description;
  final double totalAmount;
  final List<ReceiptItemModel> items;
  final List<BillSplitParticipant> participants;
  final bool includeOwner;
  final int ownerAmountSatang;
  final bool isOwnerAmountManuallyAdjusted;
  final bool isSubmitting;
  final String? errorMessage;
  final BillModel? createdBill;

  const BillCreationState({
    this.status = BillCreationStateStatus.initial,
    this.title = '',
    this.description = '',
    this.totalAmount = 0.0,
    this.items = const [],
    this.participants = const [],
    this.includeOwner = true,
    this.ownerAmountSatang = 0,
    this.isOwnerAmountManuallyAdjusted = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.createdBill,
  });

  int get totalSatang => BillSplitCalculator.toSatang(totalAmount);
  double get ownerAmountBaht => ownerAmountSatang / 100.0;

  double get itemsTotalAmount =>
      items.fold(0.0, (acc, item) => acc + (item.amount * item.quantity));

  bool get isItemsTotalMismatch =>
      items.isNotEmpty && (itemsTotalAmount - totalAmount).abs() > 0.01;

  bool get hasUnsavedChanges =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      totalAmount > 0 ||
      items.isNotEmpty ||
      participants.isNotEmpty;

  bool get isValidToReview {
    if (title.trim().isEmpty) return false;
    if (totalAmount <= 0) return false;
    if (participants.isEmpty) return false;
    return BillSplitCalculator.validateTotalInvariant(
      participants,
      totalSatang,
      ownerSatang: includeOwner ? ownerAmountSatang : 0,
    );
  }

  BillCreationState copyWith({
    BillCreationStateStatus? status,
    String? title,
    String? description,
    double? totalAmount,
    List<ReceiptItemModel>? items,
    List<BillSplitParticipant>? participants,
    bool? includeOwner,
    int? ownerAmountSatang,
    bool? isOwnerAmountManuallyAdjusted,
    bool? isSubmitting,
    String? errorMessage,
    BillModel? createdBill,
  }) {
    return BillCreationState(
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      participants: participants ?? this.participants,
      includeOwner: includeOwner ?? this.includeOwner,
      ownerAmountSatang: ownerAmountSatang ?? this.ownerAmountSatang,
      isOwnerAmountManuallyAdjusted:
          isOwnerAmountManuallyAdjusted ?? this.isOwnerAmountManuallyAdjusted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      createdBill: createdBill ?? this.createdBill,
    );
  }
}

class BillCreationNotifier extends StateNotifier<BillCreationState> {
  final BillRepository _repo;

  BillCreationNotifier(this._repo) : super(const BillCreationState());

  void _recalculateAll({
    double? newTotalAmount,
    List<BillSplitParticipant>? newParticipants,
    bool? newIncludeOwner,
    int? customOwnerSatang,
  }) {
    final total = newTotalAmount ?? state.totalAmount;
    final totalSat = BillSplitCalculator.toSatang(total);
    final parts = newParticipants ?? state.participants;
    final incOwner = newIncludeOwner ?? state.includeOwner;

    final result = BillSplitCalculator.calculateSplitWithOptions(
      participants: parts,
      totalSatang: totalSat,
      includeOwner: incOwner,
      customOwnerSatang: customOwnerSatang,
    );

    state = state.copyWith(
      totalAmount: total,
      participants: result.participants,
      includeOwner: incOwner,
      ownerAmountSatang: result.ownerSatang,
      isOwnerAmountManuallyAdjusted: customOwnerSatang != null,
      errorMessage: null,
    );
  }

  void setBillInfo({
    required String title,
    required double totalAmount,
    String description = '',
  }) {
    _recalculateAll(newTotalAmount: totalAmount);
    state = state.copyWith(
      title: title,
      description: description,
      status: BillCreationStateStatus.ready,
    );
  }

  void populateFromOcr(ReceiptOcrResultModel receipt) {
    final newItems = receipt.items;
    _recalculateAll(newTotalAmount: receipt.totalAmount);
    state = state.copyWith(
      title: receipt.merchant,
      items: newItems,
      status: BillCreationStateStatus.ready,
    );
  }

  void setIncludeOwner(bool include) {
    _recalculateAll(newIncludeOwner: include, customOwnerSatang: null);
  }

  void adjustOwnerAmount(double newAmountBaht) {
    final newSatang = BillSplitCalculator.toSatang(newAmountBaht);
    _recalculateAll(newIncludeOwner: true, customOwnerSatang: newSatang);
  }

  // --- ITEM MANAGEMENT ---
  void setItems(List<ReceiptItemModel> items) {
    state = state.copyWith(items: List.from(items), errorMessage: null);
  }

  void addItem(ReceiptItemModel item) {
    state = state.copyWith(items: [...state.items, item], errorMessage: null);
  }

  void updateItem(int index, ReceiptItemModel item) {
    if (index < 0 || index >= state.items.length) return;
    final updatedList = List<ReceiptItemModel>.from(state.items);
    updatedList[index] = item;
    state = state.copyWith(items: updatedList, errorMessage: null);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updatedList = List<ReceiptItemModel>.from(state.items)
      ..removeAt(index);
    state = state.copyWith(items: updatedList, errorMessage: null);
  }

  // --- FRIEND SELECTION & SPLIT MANAGEMENT ---
  void setSelectedFriends(List<FriendItemModel> selectedFriends) {
    final updated = selectedFriends.map((friend) {
      final friendUserId = friend.user.id ?? friend.friendshipId;
      final existing = state.participants
          .where((p) => p.userId == friendUserId)
          .firstOrNull;
      return existing ??
          BillSplitParticipant(
            userId: friendUserId,
            displayName: friend.user.displayName,
            userCode: friend.user.userCode,
            avatarUrl: friend.user.avatarUrl,
            amountSatang: 0,
          );
    }).toList();

    _recalculateAll(newParticipants: updated);
  }

  void toggleFriendSelection(FriendItemModel friend) {
    final friendUserId = friend.user.id ?? friend.friendshipId;
    final exists = state.participants.any((p) => p.userId == friendUserId);

    List<BillSplitParticipant> updated;
    if (exists) {
      updated = state.participants
          .where((p) => p.userId != friendUserId)
          .toList();
    } else {
      updated = [
        ...state.participants,
        BillSplitParticipant(
          userId: friendUserId,
          displayName: friend.user.displayName,
          userCode: friend.user.userCode,
          avatarUrl: friend.user.avatarUrl,
          amountSatang: 0,
        ),
      ];
    }

    _recalculateAll(newParticipants: updated);
  }

  void removeParticipant(String userId) {
    final updated = state.participants
        .where((p) => p.userId != userId)
        .toList();
    _recalculateAll(newParticipants: updated);
  }

  void adjustParticipantAmount(int index, double newAmountBaht) {
    final newSatang = BillSplitCalculator.toSatang(newAmountBaht);
    final ownerSat = state.includeOwner ? state.ownerAmountSatang : 0;
    final rebalanced = BillSplitCalculator.adjustParticipantAmount(
      participants: state.participants,
      totalSatang: state.totalSatang,
      targetIndex: index,
      newAmountSatang: newSatang,
      ownerSatang: ownerSat,
    );

    state = state.copyWith(participants: rebalanced, errorMessage: null);
  }

  void rebalanceEvenly() {
    _recalculateAll(customOwnerSatang: null);
  }

  // --- SUBMISSION ---
  Future<BillModel?> submitBill() async {
    // 1. Assert friend requirement and participant existence
    if (state.participants.isEmpty) {
      state = state.copyWith(
        errorMessage: 'กรุณาเลือกเพื่อนร่วมหารบิลอย่างน้อย 1 คน',
        status: BillCreationStateStatus.error,
      );
      return null;
    }

    // 2. Validate arithmetic integrity
    final ownerSat = state.includeOwner ? state.ownerAmountSatang : 0;
    if (!BillSplitCalculator.validateTotalInvariant(
      state.participants,
      state.totalSatang,
      ownerSatang: ownerSat,
    )) {
      state = state.copyWith(
        errorMessage: 'ยอดรวมส่วนแบ่งไม่ตรงกับยอดบิล กรุณาตรวจสอบ',
        status: BillCreationStateStatus.error,
      );
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      status: BillCreationStateStatus.submitting,
    );

    try {
      final participantsPayload = state.participants.map((p) {
        return {'userId': p.userId, 'amount': p.amountBaht};
      }).toList();

      final itemsPayload = state.items.map((item) {
        return {
          'name': item.name,
          'amount': item.amount,
          'quantity': item.quantity,
        };
      }).toList();

      final bill = await _repo.createBill(
        title: state.title.trim().isNotEmpty ? state.title.trim() : 'บิลอาหาร',
        description: state.description.trim().isNotEmpty
            ? state.description.trim()
            : null,
        totalAmount: state.totalAmount,
        participants: participantsPayload,
        itemsBreakdown: itemsPayload.isNotEmpty ? itemsPayload : null,
      );

      state = state.copyWith(
        isSubmitting: false,
        createdBill: bill,
        status: BillCreationStateStatus.success,
      );
      return bill;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
        status: BillCreationStateStatus.error,
      );
      return null;
    }
  }

  void reset() {
    state = const BillCreationState();
  }
}

final billCreationProvider =
    StateNotifierProvider<BillCreationNotifier, BillCreationState>((ref) {
      final repo = ref.watch(billRepositoryProvider);
      return BillCreationNotifier(repo);
    });

final billDetailProvider = FutureProvider.family<BillModel, String>((
  ref,
  billId,
) async {
  final repo = ref.watch(billRepositoryProvider);
  return repo.getBillById(billId);
});
