import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/usecase.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/restore_session.dart';

// ---------- Dependency injection ----------

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider), ref.watch(tokenStorageProvider)),
);

final loginUseCaseProvider = Provider((ref) => Login(ref.watch(authRepositoryProvider)));
final logoutUseCaseProvider = Provider((ref) => Logout(ref.watch(authRepositoryProvider)));
final restoreSessionUseCaseProvider = Provider((ref) => RestoreSession(ref.watch(authRepositoryProvider)));

// ---------- Session state ----------

/// The current user: `AsyncLoading` while restoring, `null` when logged out.
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final sub = ref.watch(sessionEventsProvider).onExpired.listen((_) => _expire());
    ref.onDispose(sub.cancel);

    final result = await ref.read(restoreSessionUseCaseProvider)(const NoParams());
    // A network error at startup should not log the user out; show login instead.
    return result.fold((_) => null, (user) => user);
  }

  void setUser(User user) => state = AsyncData(user);

  Future<void> logout() async {
    await ref.read(logoutUseCaseProvider)(const NoParams());
    state = const AsyncData(null);
  }

  Future<void> _expire() async {
    if (state.value == null) return;
    await ref.read(authRepositoryProvider).clearSession();
    state = const AsyncData(null);
  }
}

// ---------- Login form ----------

final loginControllerProvider = AsyncNotifierProvider.autoDispose<LoginController, void>(LoginController.new);

class LoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> submit({required String username, required String password}) async {
    state = const AsyncLoading();
    final result = await ref.read(loginUseCaseProvider)(LoginParams(username: username, password: password));
    if (!ref.mounted) return;
    switch (result) {
      case Success(:final value):
        ref.read(authProvider.notifier).setUser(value);
        state = const AsyncData(null);
      case Error(:final failure):
        state = AsyncError(failure, StackTrace.current);
    }
  }
}
