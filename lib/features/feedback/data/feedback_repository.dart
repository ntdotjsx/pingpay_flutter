import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/feedback_model.dart';

class FeedbackRepository {
  final DioClient _client;

  FeedbackRepository(this._client);

  /// Send user feedback or bug report directly to Discord Webhook
  Future<Map<String, dynamic>> sendFeedback(CreateFeedbackRequestModel request) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/feedback',
      data: request.toJson(),
    );
    return response.data ?? {};
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return FeedbackRepository(client);
});
