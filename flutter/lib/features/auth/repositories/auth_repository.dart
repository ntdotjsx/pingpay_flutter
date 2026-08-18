import '../../../core/network/dio_client.dart';
import '../models/auth_models.dart';

class AuthRepository {
  final DioClient _client;

  AuthRepository(this._client);

  Future<UserModel> verifyLineToken({
    String? idToken,
    String? accessToken,
    String? mockLineUserId,
    String? mockDisplayName,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/line/verify-token',
      data: {
        if (idToken != null) 'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
        if (mockLineUserId != null) 'mockLineUserId': mockLineUserId,
        if (mockDisplayName != null) 'mockDisplayName': mockDisplayName,
      },
    );

    final data = response.data;
    if (data['accessToken'] != null && data['refreshToken'] != null) {
      await _client.secureStorage.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        userId: data['user']?['id'],
      );
    }

    return await getCurrentUser();
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _client.get('/api/v1/auth/me');
    return UserModel.fromJson(response.data);
  }

  Future<PdpaConsentModel> getConsentStatus() async {
    final response = await _client.get('/api/v1/consent/current');
    return PdpaConsentModel.fromJson(response.data);
  }

  Future<void> acceptConsent() async {
    await _client.post('/api/v1/consent/accept');
  }

  Future<void> setupPin(String pin) async {
    await _client.post('/api/v1/auth/pin/setup', data: {'pin': pin});
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final res = await _client.post(
        '/api/v1/auth/pin/verify',
        data: {'pin': pin},
      );
      return res.data['valid'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? fullName,
    String? address,
    String? phoneNumber,
  }) async {
    await _client.post(
      '/api/v1/profile',
      data: {
        if (displayName != null) 'displayName': displayName,
        if (fullName != null) 'fullName': fullName,
        if (address != null) 'address': address,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      },
    );
  }

  Future<void> logout() async {
    try {
      await _client.post('/api/v1/auth/me/logout');
    } catch (_) {}
    await _client.secureStorage.clearAll();
  }
}
