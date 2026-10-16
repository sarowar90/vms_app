import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/paged.dart';
import '../../visits/domain/entities/visit_entities.dart';
import '../../visits/presentation/providers/visit_providers.dart';
import '../data/visitor_repository_impl.dart';
import '../domain/visitor_repository.dart';

// ---------- Dependency injection ----------

final visitorRepositoryProvider = Provider<VisitorRepository>(
  (ref) => VisitorRepositoryImpl(VisitorRemoteDataSource(ref.watch(apiClientProvider))),
);

final getVisitorsProvider = Provider((ref) => GetVisitors(ref.watch(visitorRepositoryProvider)));
final getVisitorDetailProvider = Provider((ref) => GetVisitorDetail(ref.watch(visitorRepositoryProvider)));
final updateVisitorProvider = Provider((ref) => UpdateVisitor(ref.watch(visitorRepositoryProvider)));
final deleteVisitorProvider = Provider((ref) => DeleteVisitor(ref.watch(visitorRepositoryProvider)));

// ---------- State ----------

/// Search text of the visitor list.
final visitorSearchProvider = NotifierProvider.autoDispose<VisitorSearch, String>(VisitorSearch.new);

class VisitorSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String q) => state = q.trim();
}

/// Paged visitor list with "load more".
final visitorListProvider = AsyncNotifierProvider.autoDispose<VisitorList, Paged<VisitorProfile>>(VisitorList.new);

class VisitorList extends AsyncNotifier<Paged<VisitorProfile>> {
  bool _loadingMore = false;

  @override
  Future<Paged<VisitorProfile>> build() {
    ref.watch(visitsRevisionProvider);
    ref.watch(visitorSearchProvider);
    return _fetch(1);
  }

  Future<Paged<VisitorProfile>> _fetch(int page) async =>
      (await ref.read(getVisitorsProvider)((q: ref.read(visitorSearchProvider), page: page))).getOrThrow();

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await _fetch(current.page + 1);
      if (!ref.mounted) return;
      state = AsyncData(
        Paged(items: [...current.items, ...next.items], total: next.total, page: next.page, lastPage: next.lastPage),
      );
    } catch (_) {
      // Keep what is shown; the user can pull to refresh.
    } finally {
      _loadingMore = false;
    }
  }
}

/// One visitor's profile + history. Reloads after visit or profile changes.
final visitorDetailProvider = FutureProvider.autoDispose.family<VisitorDetail, int>((ref, id) async {
  ref.watch(visitsRevisionProvider);
  return (await ref.watch(getVisitorDetailProvider)(id)).getOrThrow();
});

/// Save / delete state of a visitor.
class VisitorMutation extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> save(int id, VisitorInput input, {String? photo}) =>
      _run(() => ref.read(updateVisitorProvider)((id: id, input: input, photo: photo)));

  Future<bool> delete(int id) => _run(() => ref.read(deleteVisitorProvider)(id));

  Future<bool> _run(Future<Result<Object?>> Function() action) async {
    state = const AsyncLoading();
    final result = await action();
    if (!ref.mounted) return false;
    switch (result) {
      case Success():
        state = const AsyncData(null);
        // Visitor names/photos show up in visit lists too.
        ref.read(visitsRevisionProvider.notifier).bump();
        return true;
      case Error(:final failure):
        state = AsyncError(failure, StackTrace.current);
        return false;
    }
  }
}

final visitorMutationProvider = AsyncNotifierProvider.autoDispose<VisitorMutation, void>(VisitorMutation.new);
