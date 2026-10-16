import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/guard.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';
import '../../visits/presentation/providers/visit_providers.dart';
import '../data/master_repository_impl.dart';
import '../domain/master_entities.dart';
import '../domain/master_repository.dart';

// ---------- Dependency injection ----------

final branchRepositoryProvider = Provider<MasterRepository<Branch>>(
  (ref) => MasterRepositoryImpl(
    MasterRemoteDataSource(
      ref.watch(apiClientProvider),
      endpoint: 'branches',
      fromJson: branchFromJson,
      toJson: branchToJson,
    ),
  ),
);

final departmentRepositoryProvider = Provider<MasterRepository<Department>>(
  (ref) => MasterRepositoryImpl(
    MasterRemoteDataSource(
      ref.watch(apiClientProvider),
      endpoint: 'departments',
      fromJson: departmentFromJson,
      toJson: departmentToJson,
    ),
  ),
);

final employeeRepositoryProvider = Provider<MasterRepository<Employee>>(
  (ref) => MasterRepositoryImpl(
    MasterRemoteDataSource(
      ref.watch(apiClientProvider),
      endpoint: 'employees',
      fromJson: employeeFromJson,
      toJson: employeeToJson,
    ),
  ),
);

final userRepositoryProvider = Provider<MasterRepository<AppUser>>(
  (ref) => MasterRepositoryImpl(
    MasterRemoteDataSource(ref.watch(apiClientProvider), endpoint: 'users', fromJson: userFromJson, toJson: userToJson),
  ),
);

final roleRepositoryProvider = Provider<MasterRepository<Role>>(
  (ref) => MasterRepositoryImpl(
    MasterRemoteDataSource(ref.watch(apiClientProvider), endpoint: 'roles', fromJson: roleFromJson, toJson: roleToJson),
  ),
);

// ---------- State ----------

/// Bumped after any setup change; counts on other tables depend on each other
/// (a branch shows its departments / employees count).
final mastersRevisionProvider = NotifierProvider<MastersRevision, int>(MastersRevision.new);

class MastersRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

FutureProvider<List<T>> _listProvider<T extends MasterItem>(Provider<MasterRepository<T>> repo) =>
    FutureProvider.autoDispose<List<T>>((ref) async {
      ref.watch(mastersRevisionProvider);
      return (await GetMasters(ref.watch(repo))(const NoParams())).getOrThrow();
    });

final branchesProvider = _listProvider(branchRepositoryProvider);
final departmentsProvider = _listProvider(departmentRepositoryProvider);
final employeesProvider = _listProvider(employeeRepositoryProvider);
final usersProvider = _listProvider(userRepositoryProvider);
final rolesProvider = _listProvider(roleRepositoryProvider);

/// Permission groups for the role editor: (group, permission keys).
final permissionCatalogProvider = FutureProvider.autoDispose<List<(String, List<String>)>>(
  (ref) async => (await guard(() => fetchPermissionCatalog(ref.watch(apiClientProvider)))).getOrThrow(),
);

/// Save / delete of one table. `AsyncError(failure)` keeps field errors for the form.
class MasterMutation<T extends MasterItem> extends AsyncNotifier<void> {
  MasterMutation(this._repo);

  final Provider<MasterRepository<T>> _repo;

  @override
  FutureOr<void> build() {}

  Future<T?> save(T item) async {
    state = const AsyncLoading();
    final result = await SaveMaster(ref.read(_repo))(item);
    if (!ref.mounted) return null;
    switch (result) {
      case Success(:final value):
        _done();
        return value;
      case Error(:final failure):
        state = AsyncError(failure, StackTrace.current);
        return null;
    }
  }

  /// Returns the failure, or `null` when deleted.
  Future<Failure?> delete(int id) async {
    state = const AsyncLoading();
    final result = await DeleteMaster(ref.read(_repo))(id);
    if (result case Error(:final failure)) {
      if (ref.mounted) state = AsyncError(failure, StackTrace.current);
      return failure;
    }
    if (!ref.mounted) return null;
    _done();
    return null;
  }

  void reset() => state = const AsyncData(null);

  void _done() {
    state = const AsyncData(null);
    ref.read(mastersRevisionProvider.notifier).bump();
    // The host picker (check-in, pre-registration) lists employees.
    ref.invalidate(hostsProvider);
  }
}

final branchMutationProvider = AsyncNotifierProvider.autoDispose<MasterMutation<Branch>, void>(
  () => MasterMutation(branchRepositoryProvider),
);
final departmentMutationProvider = AsyncNotifierProvider.autoDispose<MasterMutation<Department>, void>(
  () => MasterMutation(departmentRepositoryProvider),
);
final userMutationProvider = AsyncNotifierProvider.autoDispose<MasterMutation<AppUser>, void>(
  () => MasterMutation(userRepositoryProvider),
);
final roleMutationProvider = AsyncNotifierProvider.autoDispose<MasterMutation<Role>, void>(
  () => MasterMutation(roleRepositoryProvider),
);
final employeeMutationProvider = AsyncNotifierProvider.autoDispose<MasterMutation<Employee>, void>(
  () => MasterMutation(employeeRepositoryProvider),
);
