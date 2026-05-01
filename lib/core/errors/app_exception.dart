abstract class AppException implements Exception {
  const AppException(this.message);

  final String message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error']);
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server error']);
}

class UnknownException extends AppException {
  const UnknownException([super.message = 'Unknown error']);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}
