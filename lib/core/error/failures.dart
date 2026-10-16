/// Failures are what the domain and presentation layers see.
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode, this.errors});

  final int? statusCode;
  final Map<String, List<String>>? errors;

  /// First validation message for a form field, if any.
  String? fieldError(String field) => errors?[field]?.first;

  /// The API answers 403 with `errors.blacklisted` when the visitor is blacklisted.
  bool get isBlacklisted => errors?.containsKey('blacklisted') ?? false;
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Session expired. Please log in again.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Cannot reach the server']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error']);
}
