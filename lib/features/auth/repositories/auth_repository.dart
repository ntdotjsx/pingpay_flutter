import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/notification_service.dart';
import '../models/auth_models.dart';

class AuthRepository {
  final DioClient _client;

  AuthRepository(this._client);

  Future<UserModel> verifyGoogleToken({
    String? idToken,
    String? accessToken,
    String? mockGoogleId,
    String? mockEmail,
    String? mockDisplayName,
  }) async {
    final metadata = await NotificationService.getDeviceMetadata();
    final response = await _client.post(
      '/api/v1/auth/google/verify-token',
      data: {
        if (idToken != null) 'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
        if (mockGoogleId != null) 'mockGoogleId': mockGoogleId,
        if (mockEmail != null) 'mockEmail': mockEmail,
        if (mockDisplayName != null) 'mockDisplayName': mockDisplayName,
        if (NotificationService.currentFcmToken != null) 'fcmToken': NotificationService.currentFcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
        ...metadata,
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
      final data = res.data;
      return data['success'] == true || data['valid'] == true;
    } catch (e) {
      if (e is AppException) {
        throw Exception(e.message);
      }
      if (e is DioException) {
        final errorMsg = (e.response?.data is Map ? e.response?.data['message'] ?? e.response?.data['error'] : null)?.toString();
        if (errorMsg != null && errorMsg.isNotEmpty) {
          throw Exception(errorMsg);
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestPinResetOtp({String? email}) async {
    try {
      final response = await _client.post(
        '/api/v1/auth/pin/forgot/request-otp',
        data: {
          if (email != null && email.isNotEmpty) 'email': email,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException) {
        final errorMsg = (e.response?.data is Map ? e.response?.data['message'] ?? e.response?.data['error'] : null)?.toString();
        if (errorMsg != null && errorMsg.isNotEmpty) {
          throw Exception(errorMsg);
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyPinResetOtp(String otp) async {
    try {
      final response = await _client.post(
        '/api/v1/auth/pin/forgot/verify-otp',
        data: {'otp': otp},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException) {
        final errorMsg = (e.response?.data is Map ? e.response?.data['message'] ?? e.response?.data['error'] : null)?.toString();
        if (errorMsg != null && errorMsg.isNotEmpty) {
          throw Exception(errorMsg);
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resetPinWithToken({
    required String resetToken,
    required String newPin,
  }) async {
    try {
      final response = await _client.post(
        '/api/v1/auth/pin/forgot/reset',
        data: {
          'resetToken': resetToken,
          'newPin': newPin,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException) {
        final errorMsg = (e.response?.data is Map ? e.response?.data['message'] ?? e.response?.data['error'] : null)?.toString();
        if (errorMsg != null && errorMsg.isNotEmpty) {
          throw Exception(errorMsg);
        }
      }
      rethrow;
    }
  }

  Future<void> changePin({
    String? currentPin,
    required String newPin,
  }) async {
    try {
      await _client.post(
        '/api/v1/auth/pin/change',
        data: {
          if (currentPin != null && currentPin.isNotEmpty) 'currentPin': currentPin,
          'newPin': newPin,
        },
      );
    } catch (e) {
      if (e is AppException) {
        throw Exception(e.message);
      }
      if (e is DioException) {
        final errorMsg = (e.response?.data is Map ? e.response?.data['message'] ?? e.response?.data['error'] : null)?.toString();
        if (errorMsg != null && errorMsg.isNotEmpty) {
          throw Exception(errorMsg);
        }
      }
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? fullName,
    String? firstName,
    String? lastName,
    String? address,
    String? phoneNumber,
    String? promptPayId,
    String? promptPayIdType,
    String? bankAccountNumber,
    String? bankName,
    String? bankCode,
    String? truemoneyPhone,
    String? shippingRecipientName,
    String? shippingPhone,
    String? shippingAddress,
  }) async {
    await _client.post(
      '/api/v1/profile',
      data: {
        if (displayName != null) 'displayName': displayName,
        if (fullName != null) 'fullName': fullName,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (address != null) 'address': address,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (promptPayId != null) 'promptPayId': promptPayId,
        if (promptPayIdType != null) 'promptPayIdType': promptPayIdType,
        if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
        if (bankName != null) 'bankName': bankName,
        if (bankCode != null) 'bankCode': bankCode,
        if (truemoneyPhone != null) 'truemoneyPhone': truemoneyPhone,
        if (shippingRecipientName != null) 'shippingRecipientName': shippingRecipientName,
        if (shippingPhone != null) 'shippingPhone': shippingPhone,
        if (shippingAddress != null) 'shippingAddress': shippingAddress,
      },
    );
  }

  Future<void> registerDeviceToken(String token) async {
    try {
      final metadata = await NotificationService.getDeviceMetadata();
      await _client.post(
        '/api/v1/notifications/device-token',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          ...metadata,
        },
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> testFcmNotification() async {
    final response = await _client.post('/api/v1/profile/test-fcm-notification');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> testLineNotification() => testFcmNotification();

  Future<void> logout() async {
    try {
      await _client.post('/api/v1/auth/me/logout');
    } catch (_) {}
    await _client.secureStorage.clearAll();
  }
}
