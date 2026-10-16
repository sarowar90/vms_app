import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/visit_entities.dart';
import 'visit_providers.dart';

/// Filters of the All Visits page (search, status chip, type, date range).
final allVisitsFilterProvider = NotifierProvider.autoDispose<AllVisitsFilter, VisitQuery>(AllVisitsFilter.new);

class AllVisitsFilter extends Notifier<VisitQuery> {
  @override
  VisitQuery build() => const VisitQuery();

  void setStatus(VisitStatus? status) => state = _with(statuses: status == null ? const [] : [status]);

  void setSearch(String q) => state = _with(q: q.trim().isEmpty ? null : q.trim());

  void setAdvanced({VisitType? visitType, DateTime? from, DateTime? to}) =>
      state = VisitQuery(statuses: state.statuses, q: state.q, visitType: visitType, from: from, to: to);

  void reset() => state = const VisitQuery();

  VisitQuery _with({List<VisitStatus>? statuses, Object? q = _keep}) => VisitQuery(
    statuses: statuses ?? state.statuses,
    q: identical(q, _keep) ? state.q : q as String?,
    visitType: state.visitType,
    from: state.from,
    to: state.to,
  );

  static const _keep = Object();
}

/// Count per status for the chips. `null` without `reports.view` (the web hides counts too).
final allVisitsCountsProvider = FutureProvider.autoDispose<Map<VisitStatus, int>?>((ref) async {
  ref.watch(visitsRevisionProvider);
  final user = ref.watch(authProvider).value;
  if (user == null || !user.can('reports.view')) return null;
  final filter = ref.watch(allVisitsFilterProvider);
  final result = await ref.watch(getVisitStatusCountsProvider)(filter);
  return result.fold((_) => null, (counts) => counts);
});
