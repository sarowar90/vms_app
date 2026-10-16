import '../../../../core/utils/result.dart';
import '../../../../core/utils/usecase.dart';
import '../repositories/auth_repository.dart';

class Logout implements UseCase<void, NoParams> {
  const Logout(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.logout();
}
