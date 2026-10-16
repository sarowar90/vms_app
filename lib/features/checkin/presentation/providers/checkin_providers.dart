import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/paged.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../visits/domain/entities/visit_entities.dart';
import '../../../visits/presentation/providers/visit_providers.dart';

/// Today's pending + approved visits ("Expected Today" list).
final expectedTodayProvider = FutureProvider.autoDispose<Paged<Visit>>((ref) async {
  ref.watch(visitsRevisionProvider);
  final today = DateTime.now();
  return (await ref.watch(getVisitsProvider)(
    VisitQuery(statuses: const [VisitStatus.pending, VisitStatus.approved], from: today, to: today, perPage: 100),
  )).getOrThrow();
});

/// Submit state of a check-in form: `AsyncData(visit)` after success,
/// `AsyncError(failure)` on failure.
class CheckinSubmit extends AsyncNotifier<Visit?> {
  @override
  FutureOr<Visit?> build() => null;

  Future<Visit?> walkIn(WalkInCheckin request) => _run(() => ref.read(checkInWalkInProvider)(request));

  Future<Visit?> existing(ExistingCheckin request) => _run(() => ref.read(checkInExistingProvider)(request));

  void reset() => state = const AsyncData(null);

  Future<Visit?> _run(Future<Result<Visit>> Function() action) async {
    state = const AsyncLoading();
    final result = await action();
    if (!ref.mounted) return null;
    switch (result) {
      case Success(:final value):
        state = AsyncData(value);
        ref.read(visitsRevisionProvider.notifier).bump();
        return value;
      case Error(:final failure):
        state = AsyncError(failure, StackTrace.current);
        return null;
    }
  }
}

final walkInSubmitProvider = AsyncNotifierProvider.autoDispose<CheckinSubmit, Visit?>(CheckinSubmit.new);
final preCheckinSubmitProvider = AsyncNotifierProvider.autoDispose<CheckinSubmit, Visit?>(CheckinSubmit.new);
