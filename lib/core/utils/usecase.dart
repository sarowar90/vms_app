import 'result.dart';

/// Base contract for a use case: one public operation of the domain.
abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// Use as `Params` for use cases that take no input.
class NoParams {
  const NoParams();
}
