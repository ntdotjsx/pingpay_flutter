import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/reward_models.dart';

class RewardRepository {
  final DioClient _client;

  RewardRepository(this._client);

  /// Fetch all active reward catalog items
  Future<List<RewardItemModel>> getRewardItems() async {
    final response = await _client.get<Map<String, dynamic>>('/api/v1/rewards/items');
    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    final itemsJson = data['items'] as List<dynamic>? ?? [];
    return itemsJson
        .map((e) => RewardItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get current user points and saved shipping address
  Future<UserPointsInfoModel> getUserPointsInfo() async {
    final response = await _client.get<Map<String, dynamic>>('/api/v1/rewards/points');
    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return UserPointsInfoModel.fromJson(data);
  }

  /// Redeem reward with shipping address
  Future<Map<String, dynamic>> redeemReward({
    required String rewardItemId,
    required String recipientName,
    required String phoneNumber,
    required String shippingAddress,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/rewards/redeem',
      data: {
        'rewardItemId': rewardItemId,
        'recipientName': recipientName,
        'phoneNumber': phoneNumber,
        'shippingAddress': shippingAddress,
      },
    );
    return response.data ?? {};
  }

  /// Get user redemption history
  Future<List<RewardRedemptionModel>> getRedemptionHistory() async {
    final response = await _client.get<Map<String, dynamic>>('/api/v1/rewards/history');
    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    final itemsJson = data['items'] as List<dynamic>? ?? [];
    return itemsJson
        .map((e) => RewardRedemptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return RewardRepository(client);
});
