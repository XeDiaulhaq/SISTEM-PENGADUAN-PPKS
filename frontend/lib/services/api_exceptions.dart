class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, 401);
}

class AuthException extends ApiException {
  AuthException(String message, [int? statusCode]) : super(message, statusCode);
}
