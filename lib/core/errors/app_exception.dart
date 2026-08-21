class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  AppException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([
    super.message =
        'Unable to connect to the server. Please check your internet connection.',
  ]);
}

class UnauthorizedException extends AppException {
  UnauthorizedException([
    super.message = 'Your session has expired. Please log in again.',
  ]) : super(statusCode: 401);
}

class ValidationException extends AppException {
  final Map<String, dynamic>? fieldErrors;
  ValidationException(super.message, {this.fieldErrors, int? statusCode})
    : super(statusCode: statusCode ?? 422);
}

class ServerException extends AppException {
  ServerException([
    super.message =
        'Something went wrong on the server. Please try again later.',
  ]) : super(statusCode: 500);
}
