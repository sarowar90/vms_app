import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../domain/entities/visit_entities.dart';
import 'visit_providers.dart';

/// Runs a visit change (approve, reject, cancel, save) and reloads visit lists on success.
/// State: `AsyncData(visit)` after success, `AsyncError(failure)` on failure.
class VisitMutation extends AsyncNotifier<Visit?> {
  @override
  FutureOr<Visit?> build() => null;

  Future<Visit?> decide(int id, VisitDecision decision, {String? remarks}) =>
      _run(() => ref.read(decideVisitProvider)((id: id, decision: decision, remarks: remarks)));

  /// Pre-register when [id] is null, otherwise update that visit.
  Future<Visit?> save({int? id, required VisitForm form}) =>
      _run(() => ref.read(saveVisitProvider)((id: id, form: form)));

  /// Returns true when deleted.
  Future<bool> delete(int id) async {
    state = const AsyncLoading();
    final result = await ref.read(deleteVisitProvider)(id);
    if (!ref.mounted) return false;
    switch (result) {
      case Success():
        state = const AsyncData(null);
        ref.read(visitsRevisionProvider.notifier).bump();
        return true;
      case Error(:final failure):
        state = AsyncError(failure, StackTrace.current);
        return false;
    }
  }

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

final visitActionProvider = AsyncNotifierProvider.autoDispose<VisitMutation, Visit?>(VisitMutation.new);
final visitFormSubmitProvider = AsyncNotifierProvider.autoDispose<VisitMutation, Visit?>(VisitMutation.new);
