import '../error/failures.dart';

/// Either a value or a [Failure]. Returned by repositories and use cases.
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) => switch (this) {
    Success(:final value) => onSuccess(value),
    Error(:final failure) => onFailure(failure),
  };

  /// For `FutureProvider`s: a thrown [Failure] becomes `AsyncError`.
  T getOrThrow() => switch (this) {
    Success(:final value) => value,
    Error(:final failure) => throw failure,
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Error<T> extends Result<T> {
  const Error(this.failure);

  final Failure failure;
}
