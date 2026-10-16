import '../../../../core/utils/result.dart';
import '../entities/user.dart';

/// Contract implemented by the data layer.
abstract interface class AuthRepository {
  Future<Result<User>> login({required String username, required String password});

  /// Returns the user for the stored token, or `null` when there is no session.
  Future<Result<User?>> restoreSession();

  Future<Result<void>> logout();

  /// Drops the stored token without calling the server (e.g. after a 401).
  Future<void> clearSession();
}
