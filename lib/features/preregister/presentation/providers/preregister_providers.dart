import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../visits/domain/entities/visit_entities.dart';
import '../../../visits/presentation/providers/visit_providers.dart';

/// The three tabs of the web pre-registration page.
enum PreregTab {
  pending('Pending', [VisitStatus.pending]),
  upcoming('Approved / Upcoming', [VisitStatus.approved]),
  closed('Rejected / Cancelled', [VisitStatus.rejected, VisitStatus.cancelled]);

  const PreregTab(this.label, this.statuses);

  final String label;
  final List<VisitStatus> statuses;

  VisitQuery get query => VisitQuery(statuses: statuses);
}

/// Badge counts on the Pending and Upcoming tabs.
final preregCountProvider = FutureProvider.autoDispose.family<int, PreregTab>((ref, tab) async {
  ref.watch(visitsRevisionProvider);
  final page = (await ref.watch(getVisitsProvider)(VisitQuery(statuses: tab.statuses, perPage: 1))).getOrThrow();
  return page.total;
});
