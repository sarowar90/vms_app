import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';
import '../../../shared/domain/entities/visit.dart';
import '../../visits/presentation/providers/visit_providers.dart';

/// Visitors inside now. Refreshes every 60 s like the web page.
final activeVisitsProvider = FutureProvider.autoDispose<List<Visit>>((ref) async {
  ref.watch(visitsRevisionProvider);
  final timer = Timer(const Duration(seconds: 60), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return (await ref.watch(getActiveVisitsProvider)(const NoParams())).getOrThrow();
});

/// Quick check-out by code / card. `AsyncData(visit)` after success.
final quickCheckoutProvider = AsyncNotifierProvider.autoDispose<QuickCheckout, Visit?>(QuickCheckout.new);

class QuickCheckout extends AsyncNotifier<Visit?> {
  @override
  FutureOr<Visit?> build() => null;

  Future<Visit?> submit(String code) async {
    state = const AsyncLoading();
    final result = await ref.read(checkoutByCodeProvider)(code);
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
