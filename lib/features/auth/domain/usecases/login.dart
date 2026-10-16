import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginParams {
  const LoginParams({required this.username, required this.password});

  final String username;
  final String password;
}

class Login implements UseCase<User, LoginParams> {
  const Login(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<User>> call(LoginParams params) async {
    final username = params.username.trim();
    if (username.isEmpty || params.password.isEmpty) {
      return const Error(ServerFailure('Username and password are required'));
    }
    return _repository.login(username: username, password: params.password);
  }
}
