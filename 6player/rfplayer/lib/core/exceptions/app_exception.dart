abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppException({required this.message, this.code, this.cause});

  @override
  String toString() => 'AppException($code): $message';
}

class DatabaseException extends AppException {
  const DatabaseException({required super.message, super.code, super.cause});
}

class FileSystemException extends AppException {
  const FileSystemException({required super.message, super.code, super.cause});
}

class PermissionException extends AppException {
  const PermissionException({required super.message, super.code, super.cause});
}

class PlayerException extends AppException {
  const PlayerException({required super.message, super.code, super.cause});
}

class NetworkException extends AppException {
  const NetworkException({required super.message, super.code, super.cause});
}
