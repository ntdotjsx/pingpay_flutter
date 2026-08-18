import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/friend_models.dart';
import '../repositories/friends_repository.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return FriendsRepository(dioClient);
});

// Friends list provider
final friendsListProvider = FutureProvider.autoDispose<List<FriendItemModel>>((
  ref,
) async {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.getFriends();
});

// Incoming friend requests provider
final incomingFriendRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequestItemModel>>((ref) async {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.getIncomingRequests();
    });

// Outgoing friend requests provider
final outgoingFriendRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequestItemModel>>((ref) async {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.getOutgoingRequests();
    });

// Single friend detail provider
final friendDetailProvider = FutureProvider.autoDispose
    .family<FriendItemModel, String>((ref, friendshipId) async {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.getFriendDetails(friendshipId);
    });

// Authoritative removal debt check provider
final removalCheckProvider = FutureProvider.autoDispose
    .family<RemovalCheckModel, String>((ref, friendshipId) async {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.checkRemoval(friendshipId);
    });

// Friend actions notifier for mutations (with double-tap protection and automatic cache invalidation)
class FriendActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const FriendActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  FriendActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return FriendActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class FriendActionsNotifier extends StateNotifier<FriendActionState> {
  final Ref _ref;
  final FriendsRepository _repo;

  FriendActionsNotifier(this._ref, this._repo)
    : super(const FriendActionState());

  void _refreshAll() {
    _ref.invalidate(friendsListProvider);
    _ref.invalidate(incomingFriendRequestsProvider);
    _ref.invalidate(outgoingFriendRequestsProvider);
  }

  Future<bool> sendRequest(String userCode) async {
    if (state.isLoading) return false;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _repo.sendFriendRequest(userCode);
      _refreshAll();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'ส่งคำขอเป็นเพื่อนเรียบร้อยแล้ว รอการตอบรับ',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> acceptRequest(String requestId) async {
    if (state.isLoading) return false;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _repo.acceptRequest(requestId);
      _refreshAll();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'ยอมรับคำขอเป็นเพื่อนแล้ว',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> rejectRequest(String requestId) async {
    if (state.isLoading) return false;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _repo.rejectRequest(requestId);
      _refreshAll();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'ปฏิเสธคำขอเป็นเพื่อนแล้ว',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    if (state.isLoading) return false;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _repo.cancelRequest(requestId);
      _refreshAll();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'ยกเลิกคำขอเป็นเพื่อนแล้ว',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> removeFriend(
    String friendshipId, {
    bool confirmOutstandingDebt = false,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _repo.removeFriend(
        friendshipId,
        confirmOutstandingDebt: confirmOutstandingDebt,
      );
      _refreshAll();
      _ref.invalidate(friendDetailProvider(friendshipId));
      _ref.invalidate(removalCheckProvider(friendshipId));
      state = state.copyWith(
        isLoading: false,
        successMessage: 'ลบเพื่อนเรียบร้อยแล้ว',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final friendActionsProvider =
    StateNotifierProvider.autoDispose<FriendActionsNotifier, FriendActionState>(
      (ref) {
        final repo = ref.watch(friendsRepositoryProvider);
        return FriendActionsNotifier(ref, repo);
      },
    );
