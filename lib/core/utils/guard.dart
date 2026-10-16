import '../error/exceptions.dart';
import '../error/failures.dart';
import 'result.dart';

/// Runs a data-layer call and converts its exceptions to [Failure]s.
/// Every repository implementation uses this.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Success(await action());
  } on ServerException catch (e) {
    if (e.statusCode == 401) return Error(UnauthorizedFailure(e.message));
    return Error(ServerFailure(e.message, statusCode: e.statusCode, errors: e.errors));
  } on NetworkException catch (e) {
    return Error(NetworkFailure(e.message));
  } on CacheException catch (e) {
    return Error(CacheFailure(e.message));
  } catch (e) {
    return Error(ServerFailure('Unexpected error: $e'));
  }
}
