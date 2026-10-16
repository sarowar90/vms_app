/// Exceptions are thrown by the data layer and converted to `Failure`s
/// in repository implementations. They never reach the presentation layer.
class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;

  /// Field validation errors from the API (`errors` key on HTTP 422).
  final Map<String, List<String>>? errors;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'Cannot reach the server']);

  final String message;
}

class CacheException implements Exception {
  const CacheException([this.message = 'Local storage error']);

  final String message;
}
