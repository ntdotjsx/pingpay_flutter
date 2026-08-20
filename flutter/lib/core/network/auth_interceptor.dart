import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Dio _dio;
  final void Function()? onUnauthorized;

  AuthInterceptor(this._storage, this._dio, {this.onUnauthorized});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add Bearer token if present
    final accessToken = await _storage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final resData = err.response?.data;
    final errorMsg = (resData is Map ? (resData['error'] ?? resData['message']) : null)?.toString() ?? '';

    final isUnauthorized = statusCode == 401 ||
        errorMsg.toLowerCase().contains('unauthorized') ||
        errorMsg.toLowerCase().contains('invalid access token');

    // Handle 401 / Unauthorized token refresh
    if (isUnauthorized && !err.requestOptions.path.contains('/auth/refresh') && !err.requestOptions.path.contains('/auth/login')) {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshDio = Dio(
            BaseOptions(baseUrl: err.requestOptions.baseUrl),
          );
          final response = await refreshDio.post(
            '/api/v1/auth/refresh',
            options: Options(
              headers: {'Cookie': 'refresh_token=$refreshToken'},
            ),
          );

          if (response.statusCode == 200 &&
              response.data['accessToken'] != null) {
            final newAccessToken = response.data['accessToken'] as String;
            final newRefreshToken =
                response.data['refreshToken'] as String? ?? refreshToken;

            await _storage.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );

            // Retry original request once
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccessToken';
            final cloneReq = await _dio.fetch(opts);
            return handler.resolve(cloneReq);
          }
        } catch (_) {
          await _storage.clearAll();
          onUnauthorized?.call();
        }
      } else {
        await _storage.clearAll();
        onUnauthorized?.call();
      }
    }
    return handler.next(err);
  }
}
