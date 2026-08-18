import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import '../errors/app_exception.dart';
import 'auth_interceptor.dart';

class DioClient {
  late final Dio dio;
  final SecureStorageService secureStorage;

  DioClient({SecureStorageService? storage, String? customBaseUrl})
    : secureStorage = storage ?? SecureStorageService() {
    dio = Dio(
      BaseOptions(
        baseUrl: customBaseUrl ?? AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(AuthInterceptor(secureStorage, dio));
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  AppException _mapDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return NetworkException();
    }

    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;
    final errorMessage = responseData is Map
        ? (responseData['error'] ?? responseData['message'])
        : null;

    if (statusCode == 401) {
      return UnauthorizedException(
        errorMessage?.toString() ?? 'Session expired',
      );
    }
    if (statusCode == 400 || statusCode == 422) {
      return ValidationException(errorMessage?.toString() ?? 'Invalid request');
    }
    if (statusCode == 500) {
      return ServerException(
        errorMessage?.toString() ?? 'Internal server error',
      );
    }

    return AppException(
      errorMessage?.toString() ?? 'An unexpected error occurred',
      statusCode: statusCode,
    );
  }
}
