import '../../../core/network/dio_client.dart';
import '../models/friend_models.dart';

class FriendsRepository {
  final DioClient _client;

  FriendsRepository(this._client);

  Future<UserSearchModel?> searchUser(String userCode) async {
    final cleanCode = userCode.trim();
    if (cleanCode.isEmpty) return null;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/users/search',
        queryParameters: {'userCode': cleanCode},
      );

      final data = response.data?['data'];
      if (data != null && data['user'] != null) {
        return UserSearchModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      if (e.toString().contains('USER_NOT_FOUND')) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<FriendItemModel>> getFriends({int limit = 50}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/friends',
      queryParameters: {'limit': limit},
    );

    final data = response.data?['data'];
    final items = data?['items'] as List? ?? [];
    return items
        .map((e) => FriendItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FriendItemModel> getFriendDetails(String friendshipId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/friends/$friendshipId',
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return FriendItemModel.fromJson(data);
  }

  Future<List<FriendRequestItemModel>> getIncomingRequests({
    int limit = 50,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/friends/requests/incoming',
      queryParameters: {'limit': limit},
    );

    final data = response.data?['data'];
    final items = data?['items'] as List? ?? [];
    return items
        .map((e) => FriendRequestItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequestItemModel>> getOutgoingRequests({
    int limit = 50,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/friends/requests/outgoing',
      queryParameters: {'limit': limit},
    );

    final data = response.data?['data'];
    final items = data?['items'] as List? ?? [];
    return items
        .map((e) => FriendRequestItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendFriendRequest(String userCode) async {
    try {
      await _client.post(
        '/api/v1/friends/requests',
        data: {'userCode': userCode.trim()},
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('CANNOT_ADD_SELF')) {
        throw Exception('ไม่สามารถส่งคำขอเป็นเพื่อนให้ตัวเองได้');
      } else if (msg.contains('ALREADY_FRIENDS')) {
        throw Exception('คุณและผู้ใช้นี้เป็นเพื่อนกันอยู่แล้ว');
      } else if (msg.contains('FRIEND_REQUEST_ALREADY_SENT')) {
        throw Exception('คุณได้ส่งคำขอเป็นเพื่อนไปแล้ว รอการตอบรับ');
      } else if (msg.contains('INCOMING_FRIEND_REQUEST_EXISTS')) {
        throw Exception('ผู้ใช้นี้ได้ส่งคำขอหาคุณแล้ว กรุณาตรวจสอบในกล่องคำขอ');
      } else if (msg.contains('USER_NOT_FOUND')) {
        throw Exception('ไม่พบผู้ใช้งานนี้ในระบบ');
      }
      rethrow;
    }
  }

  Future<void> acceptRequest(String requestId) async {
    await _client.post('/api/v1/friends/requests/$requestId/accept');
  }

  Future<void> rejectRequest(String requestId) async {
    await _client.post('/api/v1/friends/requests/$requestId/reject');
  }

  Future<void> cancelRequest(String requestId) async {
    await _client.post('/api/v1/friends/requests/$requestId/cancel');
  }

  Future<RemovalCheckModel> checkRemoval(String friendshipId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/friends/$friendshipId/removal-check',
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return RemovalCheckModel.fromJson(data);
  }

  Future<void> removeFriend(
    String friendshipId, {
    bool confirmOutstandingDebt = false,
  }) async {
    await _client.post(
      '/api/v1/friends/$friendshipId/remove',
      data: {'confirmOutstandingDebt': confirmOutstandingDebt},
    );
  }
}
