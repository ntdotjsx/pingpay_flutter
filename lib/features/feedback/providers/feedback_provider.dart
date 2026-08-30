import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/feedback_repository.dart';
import '../models/feedback_model.dart';

class FeedbackSubmitState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final String? successMessage;

  const FeedbackSubmitState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.successMessage,
  });

  FeedbackSubmitState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    String? successMessage,
  }) {
    return FeedbackSubmitState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class FeedbackNotifier extends StateNotifier<FeedbackSubmitState> {
  final FeedbackRepository _repository;

  FeedbackNotifier(this._repository) : super(const FeedbackSubmitState());

  Future<bool> submitFeedback(CreateFeedbackRequestModel request) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);
    try {
      final res = await _repository.sendFeedback(request);
      final msg = res['message'] as String? ?? 'ส่งข้อเสนอแนะเรียบร้อยแล้ว ขอบคุณครับ!';
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: msg,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() {
    state = const FeedbackSubmitState();
  }
}

final feedbackNotifierProvider =
    StateNotifierProvider.autoDispose<FeedbackNotifier, FeedbackSubmitState>((ref) {
  final repo = ref.watch(feedbackRepositoryProvider);
  return FeedbackNotifier(repo);
});
