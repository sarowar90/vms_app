import '../../../../core/utils/result.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RestoreSession implements UseCase<User?, NoParams> {
  const RestoreSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<User?>> call(NoParams params) => _repository.restoreSession();
}
