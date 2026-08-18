import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Dio _dio;

  AuthInterceptor(this._storage, this._dio);

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
    // Handle 401 token refresh if needed
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/refresh')) {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
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
        }
      }
    }
    return handler.next(err);
  }
}
