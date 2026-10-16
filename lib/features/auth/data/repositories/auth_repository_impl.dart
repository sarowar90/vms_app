import '../../../../core/error/failures.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../../../core/utils/guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  @override
  Future<Result<User>> login({required String username, required String password}) =>
      guard(() async {
        final response = await _remote.login(username, password);
        await _tokens.write(response.token);
        return response.user;
      });

  @override
  Future<Result<User?>> restoreSession() async {
    if (_tokens.read() == null) return const Success(null);
    final result = await guard(_remote.me);
    if (result case Error(failure: UnauthorizedFailure())) {
      await _tokens.clear();
      return const Success(null);
    }
    return result;
  }

  @override
  Future<Result<void>> logout() async {
    // Log out locally even if the server call fails.
    final result = await guard(_remote.logout);
    await _tokens.clear();
    return result;
  }

  @override
  Future<void> clearSession() => _tokens.clear();
}
