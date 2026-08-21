import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bills/repositories/bill_repository.dart';
import '../models/payment_models.dart';
import '../repositories/payment_repository.dart';

enum DebtFilter {
  all, // ทั้งหมด
  unpaid, // ค้างชำระ
  partiallyPaid, // ชำระบางส่วน
  pendingConfirmation, // รอยืนยัน
  history, // ประวัติ (ชำระแล้ว/ตัดหนี้)
}

enum DebtSortOption {
  mostOverdue, // ค้างนานสุดก่อน (default)
  newest, // บิลล่าสุด
  highestAmount, // ยอดค้างสูงสุด
  lowestAmount, // ยอดค้างต่ำสุด
}

class UserDebtsState {
  final bool isLoading;
  final String? errorMessage;
  final DebtSummaryModel summary;
  final List<DebtItemModel> allDebts;
  final DebtFilter currentFilter;
  final DebtSortOption currentSort;

  const UserDebtsState({
    this.isLoading = false,
    this.errorMessage,
    this.summary = const DebtSummaryModel(
      outstandingCount: 0,
      totalOutstandingAmount: 0.0,
    ),
    this.allDebts = const [],
    this.currentFilter = DebtFilter.unpaid,
    this.currentSort = DebtSortOption.mostOverdue,
  });

  UserDebtsState copyWith({
    bool? isLoading,
    String? errorMessage,
    DebtSummaryModel? summary,
    List<DebtItemModel>? allDebts,
    DebtFilter? currentFilter,
    DebtSortOption? currentSort,
  }) {
    return UserDebtsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      summary: summary ?? this.summary,
      allDebts: allDebts ?? this.allDebts,
      currentFilter: currentFilter ?? this.currentFilter,
      currentSort: currentSort ?? this.currentSort,
    );
  }

  /// Outstanding debts specifically for the primary actionable list (unpaid & partially paid that are acknowledged)
  List<DebtItemModel> get outstandingDebts {
    return allDebts
        .where((d) => d.isOutstanding && d.outstandingAmount > 0 && d.isAcknowledged)
        .toList();
  }

  /// Filtered and sorted debts according to user selections (only acknowledged debts)
  List<DebtItemModel> get filteredDebts {
    final acknowledgedDebts = allDebts.where((d) => d.isAcknowledged).toList();
    List<DebtItemModel> result;

    switch (currentFilter) {
      case DebtFilter.all:
        result = List.from(acknowledgedDebts);
        break;
      case DebtFilter.unpaid:
        result = acknowledgedDebts
            .where((d) => d.isOutstanding && d.amountPaid == 0)
            .toList();
        break;
      case DebtFilter.partiallyPaid:
        result = acknowledgedDebts.where((d) => d.isPartiallyPaid).toList();
        break;
      case DebtFilter.pendingConfirmation:
        result = acknowledgedDebts
            .where((d) => d.latestPaymentStatus == 'pending_owner_confirmation')
            .toList();
        break;
      case DebtFilter.history:
        result = acknowledgedDebts
            .where((d) => !d.isOutstanding || d.outstandingAmount <= 0)
            .toList();
        break;
    }

    // Sort result
    switch (currentSort) {
      case DebtSortOption.mostOverdue:
        result.sort(
          (a, b) => a.debtStartDate.compareTo(b.debtStartDate),
        ); // Oldest start date first = most overdue
        break;
      case DebtSortOption.newest:
        result.sort((a, b) => b.debtStartDate.compareTo(a.debtStartDate));
        break;
      case DebtSortOption.highestAmount:
        result.sort(
          (a, b) => b.outstandingAmount.compareTo(a.outstandingAmount),
        );
        break;
      case DebtSortOption.lowestAmount:
        result.sort(
          (a, b) => a.outstandingAmount.compareTo(b.outstandingAmount),
        );
        break;
    }

    return result;
  }
}

class UserDebtsNotifier extends StateNotifier<UserDebtsState> {
  final PaymentRepository _repository;

  UserDebtsNotifier(this._repository) : super(const UserDebtsState()) {
    loadDebts();
  }

  Future<void> loadDebts({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final response = await _repository.getUserDebtsAndSummary();
      state = state.copyWith(
        isLoading: false,
        summary: response.summary,
        allDebts: response.debts,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  Future<void> acknowledgeDebt(String billItemId) async {
    try {
      await _repository.acknowledgeDebt(billItemId);
      await loadDebts(showLoading: false);
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      rethrow;
    }
  }

  void setFilter(DebtFilter filter) {
    state = state.copyWith(currentFilter: filter);
  }

  void setSort(DebtSortOption sort) {
    state = state.copyWith(currentSort: sort);
  }
}

final userDebtsProvider =
    StateNotifierProvider<UserDebtsNotifier, UserDebtsState>((ref) {
      final repo = ref.watch(paymentRepositoryProvider);
      return UserDebtsNotifier(repo);
    });

final paymentSummaryProvider = Provider<DebtSummaryModel>((ref) {
  return ref.watch(userDebtsProvider).summary;
});

/// Count of unacknowledged debt requests waiting for user swipe acceptance (Badge for Bell)
final pendingDebtRequestsCountProvider = Provider<int>((ref) {
  final allDebts = ref.watch(userDebtsProvider).allDebts;
  return allDebts.where((d) => !d.isAcknowledged && d.isOutstanding && d.outstandingAmount > 0).length;
});

final pendingDebtRequestsProvider = Provider<List<DebtItemModel>>((ref) {
  final allDebts = ref.watch(userDebtsProvider).allDebts;
  return allDebts.where((d) => !d.isAcknowledged && d.isOutstanding && d.outstandingAmount > 0).toList();
});

final outstandingDebtsCountProvider = Provider<int>((ref) {
  return ref.watch(userDebtsProvider).summary.outstandingCount;
});

final outstandingTotalAmountProvider = Provider<double>((ref) {
  return ref.watch(userDebtsProvider).summary.totalOutstandingAmount;
});

/// Payment Submission Flow Notifier for a single active payment
enum PaymentFlowStatus { initial, submitting, slipOkPassed, success, error }

class PaymentFlowState {
  final PaymentFlowStatus status;
  final bool isSubmitting;
  final String? errorMessage;
  final CreatePaymentResultModel? result;

  const PaymentFlowState({
    this.status = PaymentFlowStatus.initial,
    this.isSubmitting = false,
    this.errorMessage,
    this.result,
  });

  PaymentFlowState copyWith({
    PaymentFlowStatus? status,
    bool? isSubmitting,
    String? errorMessage,
    CreatePaymentResultModel? result,
  }) {
    return PaymentFlowState(
      status: status ?? this.status,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      result: result ?? this.result,
    );
  }
}

class PaymentFlowNotifier extends StateNotifier<PaymentFlowState> {
  final PaymentRepository _repo;
  final Ref _ref;

  PaymentFlowNotifier(this._repo, this._ref) : super(const PaymentFlowState());

  Future<CreatePaymentResultModel?> submitPayment({
    required String billId,
    required String participantId,
    required double amount,
    File? slipFile,
    String? qrData,
    String? method,
  }) async {
    if (state.isSubmitting) return null; // Prevent double submission

    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      status: PaymentFlowStatus.submitting,
    );

    try {
      final res = await _repo.submitPaymentWithSlip(
        billId: billId,
        participantId: participantId,
        amount: amount,
        slipFile: slipFile,
        qrData: qrData,
        method: method,
        idempotencyKey:
            'PAY_${participantId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      state = state.copyWith(
        isSubmitting: false,
        result: res,
        status: res.slipOkVerified
            ? PaymentFlowStatus.slipOkPassed
            : PaymentFlowStatus.success,
      );

      // Refresh debts list from authoritative backend
      _ref.read(userDebtsProvider.notifier).loadDebts(showLoading: false);

      return res;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
        status: PaymentFlowStatus.error,
      );
      return null;
    }
  }

  void reset() {
    state = const PaymentFlowState();
  }
}

final paymentFlowProvider =
    StateNotifierProvider<PaymentFlowNotifier, PaymentFlowState>((ref) {
      final repo = ref.watch(paymentRepositoryProvider);
      return PaymentFlowNotifier(repo, ref);
    });

final billPaymentHistoryProvider =
    FutureProvider.family<List<PaymentInstallmentModel>, String>((
      ref,
      billId,
    ) async {
      final repo = ref.watch(paymentRepositoryProvider);
      return repo.getBillPaymentHistory(billId);
    });

// ==========================================
// RECEIVABLES STATE & NOTIFIER (เพื่อนติดเรา)
// ==========================================

enum ReceivableFilter {
  all, // ทั้งหมด (มีหนี้ค้าง)
  overdue, // ค้างนาน (> 7 วัน)
  partiallyPaid, // ชำระบางส่วน
  pendingConfirmation, // รอยืนยัน
  history, // ชำระครบแล้ว
}

enum ReceivableSortOption {
  mostOverdue, // ค้างนานสุดก่อน (default)
  highestAmount, // ยอดค้างสูงสุด
  lowestAmount, // ยอดค้างต่ำสุด
  name, // เรียงตามชื่อ
}

class UserReceivablesState {
  final bool isLoading;
  final String? errorMessage;
  final ReceivableSummaryModel summary;
  final List<ReceivableFriendModel> allFriends;
  final ReceivableFilter currentFilter;
  final ReceivableSortOption currentSort;
  final String searchQuery;

  const UserReceivablesState({
    this.isLoading = false,
    this.errorMessage,
    this.summary = const ReceivableSummaryModel(
      debtorCount: 0,
      totalOutstandingAmount: 0.0,
    ),
    this.allFriends = const [],
    this.currentFilter = ReceivableFilter.all,
    this.currentSort = ReceivableSortOption.mostOverdue,
    this.searchQuery = '',
  });

  UserReceivablesState copyWith({
    bool? isLoading,
    String? errorMessage,
    ReceivableSummaryModel? summary,
    List<ReceivableFriendModel>? allFriends,
    ReceivableFilter? currentFilter,
    ReceivableSortOption? currentSort,
    String? searchQuery,
  }) {
    return UserReceivablesState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      summary: summary ?? this.summary,
      allFriends: allFriends ?? this.allFriends,
      currentFilter: currentFilter ?? this.currentFilter,
      currentSort: currentSort ?? this.currentSort,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Outstanding friends who currently owe money (> 0)
  List<ReceivableFriendModel> get outstandingFriends {
    return allFriends.where((f) => f.hasOutstandingDebt).toList();
  }

  /// Filtered and sorted friends list based on active filters and search query
  List<ReceivableFriendModel> get filteredFriends {
    List<ReceivableFriendModel> result;

    switch (currentFilter) {
      case ReceivableFilter.all:
        result = allFriends.where((f) => f.hasOutstandingDebt).toList();
        break;
      case ReceivableFilter.overdue:
        final now = DateTime.now();
        result = allFriends
            .where(
              (f) =>
                  f.hasOutstandingDebt &&
                  now.difference(f.oldestDebtStartDate).inDays >= 7,
            )
            .toList();
        break;
      case ReceivableFilter.partiallyPaid:
        result = allFriends
            .where((f) => f.hasOutstandingDebt && f.totalAmountPaid > 0)
            .toList();
        break;
      case ReceivableFilter.pendingConfirmation:
        result = allFriends
            .where((f) => f.latestPaymentStatus == 'pending_owner_confirmation')
            .toList();
        break;
      case ReceivableFilter.history:
        result = allFriends.where((f) => !f.hasOutstandingDebt).toList();
        break;
    }

    // Apply search query filter if present
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((f) {
        return f.debtor.displayName.toLowerCase().contains(q) ||
            f.debtor.userCode.toLowerCase().contains(q);
      }).toList();
    }

    // Apply Sorting
    switch (currentSort) {
      case ReceivableSortOption.mostOverdue:
        result.sort(
          (a, b) => a.oldestDebtStartDate.compareTo(b.oldestDebtStartDate),
        );
        break;
      case ReceivableSortOption.highestAmount:
        result.sort(
          (a, b) =>
              b.totalOutstandingAmount.compareTo(a.totalOutstandingAmount),
        );
        break;
      case ReceivableSortOption.lowestAmount:
        result.sort(
          (a, b) =>
              a.totalOutstandingAmount.compareTo(b.totalOutstandingAmount),
        );
        break;
      case ReceivableSortOption.name:
        result.sort(
          (a, b) => a.debtor.displayName.compareTo(b.debtor.displayName),
        );
        break;
    }

    return result;
  }
}

class UserReceivablesNotifier extends StateNotifier<UserReceivablesState> {
  final PaymentRepository _repo;
  final Ref _ref;

  UserReceivablesNotifier(this._repo, this._ref)
      : super(const UserReceivablesState()) {
    loadReceivables();
  }

  Future<void> loadReceivables({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final response = await _repo.getUserReceivablesAndSummary();
      state = state.copyWith(
        isLoading: false,
        summary: response.summary,
        allFriends: response.friends,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  void setFilter(ReceivableFilter filter) {
    state = state.copyWith(currentFilter: filter);
  }

  void setSort(ReceivableSortOption sort) {
    state = state.copyWith(currentSort: sort);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Confirm payment received as bill owner
  Future<bool> confirmPaymentReceived(String paymentId) async {
    try {
      final idempotencyKey =
          'CONFIRM_${paymentId}_${DateTime.now().millisecondsSinceEpoch}';
      await _repo.confirmPayment(
        paymentId: paymentId,
        idempotencyKey: idempotencyKey,
      );
      // Reload authoritative data
      await loadReceivables(showLoading: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel whole bill and instantly reload receivables to clear the debts
  Future<bool> cancelBill(String billId, {String? reason}) async {
    try {
      final billRepo = _ref.read(billRepositoryProvider);
      await billRepo.cancelBill(billId: billId, reason: reason);
      await loadReceivables(showLoading: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Write off / ยกเลิกหนี้เฉพาะรายการของเพื่อน และอัปเดตยอดเพื่อนติดเราทันที
  Future<bool> writeOffDebt({
    required String billId,
    required String participantId,
    required double amount,
    String? reason,
  }) async {
    try {
      final billRepo = _ref.read(billRepositoryProvider);
      final idempotencyKey =
          'WRITEOFF_${participantId}_${DateTime.now().millisecondsSinceEpoch}';
      await billRepo.writeOffDebt(
        billId: billId,
        participants: [
          {'participantId': participantId, 'amount': amount}
        ],
        reason: reason,
        idempotencyKey: idempotencyKey,
      );
      await loadReceivables(showLoading: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Edit / แก้ไขยอดหนี้เฉพาะรายการของเพื่อน และอัปเดตยอดเพื่อนติดเราทันที
  Future<bool> editParticipantAmount({
    required String billId,
    required String participantId,
    required double newAmount,
  }) async {
    try {
      final billRepo = _ref.read(billRepositoryProvider);
      await billRepo.editParticipantAmount(
        billId: billId,
        participantId: participantId,
        newAmount: newAmount,
      );
      await loadReceivables(showLoading: false);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final userReceivablesProvider =
    StateNotifierProvider<UserReceivablesNotifier, UserReceivablesState>((ref) {
      final repo = ref.watch(paymentRepositoryProvider);
      return UserReceivablesNotifier(repo, ref);
    });

final receivableSummaryProvider = Provider<ReceivableSummaryModel>((ref) {
  return ref.watch(userReceivablesProvider).summary;
});

final outstandingDebtorsCountProvider = Provider<int>((ref) {
  return ref.watch(userReceivablesProvider).summary.debtorCount;
});
