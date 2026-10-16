import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/usecase.dart';
import '../../../../shared/domain/entities/paged.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../data/datasources/visit_remote_data_source.dart';
import '../../data/repositories/visit_repository_impl.dart';
import '../../domain/entities/visit_entities.dart';
import '../../domain/repositories/visit_repository.dart';
import '../../domain/usecases/visit_use_cases.dart';

// ---------- Dependency injection ----------

final visitRepositoryProvider = Provider<VisitRepository>(
  (ref) => VisitRepositoryImpl(VisitRemoteDataSource(ref.watch(apiClientProvider))),
);

final getHostsProvider = Provider((ref) => GetHosts(ref.watch(visitRepositoryProvider)));
final searchVisitorsProvider = Provider((ref) => SearchVisitors(ref.watch(visitRepositoryProvider)));
final checkBlacklistProvider = Provider((ref) => CheckBlacklist(ref.watch(visitRepositoryProvider)));
final getVisitsProvider = Provider((ref) => GetVisits(ref.watch(visitRepositoryProvider)));
final getVisitProvider = Provider((ref) => GetVisit(ref.watch(visitRepositoryProvider)));
final lookupVisitProvider = Provider((ref) => LookupVisit(ref.watch(visitRepositoryProvider)));
final checkInWalkInProvider = Provider((ref) => CheckInWalkIn(ref.watch(visitRepositoryProvider)));
final checkInExistingProvider = Provider((ref) => CheckInExisting(ref.watch(visitRepositoryProvider)));
final saveVisitProvider = Provider((ref) => SaveVisit(ref.watch(visitRepositoryProvider)));
final decideVisitProvider = Provider((ref) => DecideVisit(ref.watch(visitRepositoryProvider)));
final getActiveVisitsProvider = Provider((ref) => GetActiveVisits(ref.watch(visitRepositoryProvider)));
final checkoutByCodeProvider = Provider((ref) => CheckoutByCode(ref.watch(visitRepositoryProvider)));
final deleteVisitProvider = Provider((ref) => DeleteVisit(ref.watch(visitRepositoryProvider)));
final getVisitStatusCountsProvider = Provider((ref) => GetVisitStatusCounts(ref.watch(visitRepositoryProvider)));

// ---------- Shared state ----------

/// Active employees for the host picker.
final hostsProvider = FutureProvider.autoDispose<List<Host>>(
  (ref) async => (await ref.watch(getHostsProvider)(const NoParams())).getOrThrow(),
);

/// One filtered, paged visit list with "load more" for infinite scrolling.
/// Used by All Visits and the Pre-registration tabs. [query]'s page is ignored.
class VisitList extends AsyncNotifier<Paged<Visit>> {
  VisitList(this.query);

  final VisitQuery query;
  bool _loadingMore = false;

  @override
  Future<Paged<Visit>> build() {
    ref.watch(visitsRevisionProvider);
    return _fetch(1);
  }

  Future<Paged<Visit>> _fetch(int page) async =>
      (await ref.read(getVisitsProvider)(query.copyWith(page: page))).getOrThrow();

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

final visitListProvider = AsyncNotifierProvider.autoDispose.family<VisitList, Paged<Visit>, VisitQuery>(VisitList.new);

/// Bumped after any visit is created or changed, so every visit list
/// (dashboard, expected today, pre-registrations) reloads.
final visitsRevisionProvider = NotifierProvider<VisitsRevision, int>(VisitsRevision.new);

class VisitsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
