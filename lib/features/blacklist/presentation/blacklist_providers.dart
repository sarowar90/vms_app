import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';
import '../../visits/presentation/providers/visit_providers.dart';
import '../data/blacklist_repository_impl.dart';
import '../domain/blacklist_repository.dart';

// ---------- Dependency injection ----------

final blacklistRepositoryProvider = Provider<BlacklistRepository>(
  (ref) => BlacklistRepositoryImpl(BlacklistRemoteDataSource(ref.watch(apiClientProvider))),
);

final getBlacklistProvider = Provider((ref) => GetBlacklist(ref.watch(blacklistRepositoryProvider)));
final saveBlacklistEntryProvider = Provider((ref) => SaveBlacklistEntry(ref.watch(blacklistRepositoryProvider)));
final deleteBlacklistEntryProvider = Provider((ref) => DeleteBlacklistEntry(ref.watch(blacklistRepositoryProvider)));

// ---------- State ----------

/// All entries of the company (the API does not paginate this list).
final blacklistProvider = FutureProvider.autoDispose<List<BlacklistItem>>((ref) async {
  ref.watch(visitsRevisionProvider);
  return (await ref.watch(getBlacklistProvider)(const NoParams())).getOrThrow();
});

class BlacklistMutation extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> save({int? id, required BlacklistInput input}) =>
      _run(() => ref.read(saveBlacklistEntryProvider)((id: id, input: input)));

  Future<bool> delete(int id) => _run(() => ref.read(deleteBlacklistEntryProvider)(id));

  Future<bool> _run(Future<Result<Object?>> Function() action) async {
    state = const AsyncLoading();
    final result = await action();
    if (!ref.mounted) return false;
    switch (result) {
      case Success():
        state = const AsyncData(null);
        // The blacklisted flag shows on visitor profiles and search results too.
        ref.read(visitsRevisionProvider.notifier).bump();
        return true;
      case Error(:final failure):
        state = AsyncError(failure, StackTrace.current);
        return false;
    }
  }
}

final blacklistMutationProvider = AsyncNotifierProvider.autoDispose<BlacklistMutation, void>(BlacklistMutation.new);
