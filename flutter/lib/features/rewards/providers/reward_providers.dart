import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/reward_models.dart';
import '../repositories/reward_repository.dart';

final rewardCatalogProvider = FutureProvider.autoDispose<List<RewardItemModel>>((ref) async {
  final repo = ref.watch(rewardRepositoryProvider);
  return repo.getRewardItems();
});

final redemptionHistoryProvider = FutureProvider.autoDispose<List<RewardRedemptionModel>>((ref) async {
  final repo = ref.watch(rewardRepositoryProvider);
  return repo.getRedemptionHistory();
});

class RewardStoreState {
  final int points;
  final String? shippingAddress;
  final String? shippingPhone;
  final String? shippingRecipientName;
  final bool isRedeeming;
  final String? errorMessage;
  final String? successMessage;

  const RewardStoreState({
    this.points = 27,
    this.shippingAddress,
    this.shippingPhone,
    this.shippingRecipientName,
    this.isRedeeming = false,
    this.errorMessage,
    this.successMessage,
  });

  RewardStoreState copyWith({
    int? points,
    String? shippingAddress,
    String? shippingPhone,
    String? shippingRecipientName,
    bool? isRedeeming,
    String? errorMessage,
    String? successMessage,
  }) {
    return RewardStoreState(
      points: points ?? this.points,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      shippingPhone: shippingPhone ?? this.shippingPhone,
      shippingRecipientName: shippingRecipientName ?? this.shippingRecipientName,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class RewardStoreNotifier extends StateNotifier<RewardStoreState> {
  final RewardRepository _repo;
  final Ref _ref;

  RewardStoreNotifier(this._repo, this._ref) : super(const RewardStoreState()) {
    loadUserPointsInfo();
  }

  Future<void> loadUserPointsInfo() async {
    try {
      final info = await _repo.getUserPointsInfo();
      state = state.copyWith(
        points: info.rewardPoints,
        shippingAddress: info.shippingAddress,
        shippingPhone: info.shippingPhone,
        shippingRecipientName: info.shippingRecipientName,
      );
    } catch (e) {
      // Keep existing state on error
    }
  }

  Future<bool> redeemReward({
    required String rewardItemId,
    required String recipientName,
    required String phoneNumber,
    required String shippingAddress,
  }) async {
    state = state.copyWith(isRedeeming: true, errorMessage: null, successMessage: null);
    try {
      final result = await _repo.redeemReward(
        rewardItemId: rewardItemId,
        recipientName: recipientName,
        phoneNumber: phoneNumber,
        shippingAddress: shippingAddress,
      );

      final message = result['message'] as String? ?? 'แลกรับของรางวัลสำเร็จ!';
      final data = result['data'] as Map<String, dynamic>? ?? {};
      final remaining = data['remainingPoints'] as int? ?? (state.points);

      state = state.copyWith(
        isRedeeming: false,
        points: remaining,
        shippingAddress: shippingAddress,
        shippingPhone: phoneNumber,
        shippingRecipientName: recipientName,
        successMessage: message,
      );

      // Refresh catalog and user auth session state
      _ref.invalidate(rewardCatalogProvider);
      _ref.invalidate(redemptionHistoryProvider);
      _ref.read(authStateProvider.notifier).checkSession();

      return true;
    } catch (e) {
      state = state.copyWith(
        isRedeeming: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }
}

final rewardStoreProvider =
    StateNotifierProvider<RewardStoreNotifier, RewardStoreState>((ref) {
  final repo = ref.watch(rewardRepositoryProvider);
  return RewardStoreNotifier(repo, ref);
});
