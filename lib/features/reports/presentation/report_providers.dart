import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/utils/usecase.dart';
import '../../visits/presentation/providers/visit_providers.dart';
import '../data/report_repository_impl.dart';
import '../domain/report_entities.dart';
import '../domain/report_repository.dart';
import '../domain/report_use_cases.dart';

// ---------- Dependency injection ----------

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepositoryImpl(
    ReportRemoteDataSource(ref.watch(apiClientProvider)),
    ReportLocalDataSource(ref.watch(sharedPreferencesProvider)),
  ),
);

final getReportColumnsProvider = Provider((ref) => GetReportColumns(ref.watch(reportRepositoryProvider)));
final getReportPageProvider = Provider((ref) => GetReportPage(ref.watch(reportRepositoryProvider)));
final getReportSummaryProvider = Provider((ref) => GetReportSummary(ref.watch(reportRepositoryProvider)));
final exportReportProvider = Provider((ref) => ExportReport(ref.watch(reportRepositoryProvider)));

// ---------- State ----------

final reportColumnsProvider = FutureProvider.autoDispose<List<ReportColumn>>(
  (ref) async => (await ref.watch(getReportColumnsProvider)(const NoParams())).getOrThrow(),
);

final reportDepartmentsProvider = FutureProvider.autoDispose<List<NamedOption>>(
  (ref) async => (await ref.watch(reportRepositoryProvider).departments()).getOrThrow(),
);

final reportBranchesProvider = FutureProvider.autoDispose<List<NamedOption>>(
  (ref) async => (await ref.watch(reportRepositoryProvider).branches()).getOrThrow(),
);

/// Current filters. Starts with "This Month", like the web.
final reportFilterProvider = NotifierProvider.autoDispose<ReportFilterNotifier, ReportFilter>(ReportFilterNotifier.new);

class ReportFilterNotifier extends Notifier<ReportFilter> {
  @override
  ReportFilter build() {
    final (from, to) = ReportRange.month.dates(DateTime.now());
    return ReportFilter(from: from, to: to);
  }

  void set(ReportFilter filter) => state = filter;

  void range(ReportRange r) {
    final (from, to) = r.dates(DateTime.now());
    state = state.withDates(from, to);
  }

  /// Web "Reset": clear everything and go back to this month.
  void reset() => state = build();
}

/// Chosen columns and sort, remembered on this device. `null` until the columns are known.
final reportLayoutProvider = NotifierProvider.autoDispose<ReportLayoutNotifier, ReportLayout?>(
  ReportLayoutNotifier.new,
);

class ReportLayoutNotifier extends Notifier<ReportLayout?> {
  @override
  ReportLayout? build() {
    final columns = ref.watch(reportColumnsProvider).value;
    if (columns == null) return null;
    final known = {for (final c in columns) c.key};
    final saved = ref.read(reportRepositoryProvider).savedLayout();
    final kept = saved?.columns.where(known.contains).toList() ?? const <String>[];
    return ReportLayout(
      columns: kept.isNotEmpty
          ? kept
          : [
              for (final c in columns)
                if (c.isDefault) c.key,
            ],
      sort: saved?.sort ?? 'check_in_at',
      descending: saved?.descending ?? true,
    );
  }

  void set(ReportLayout layout) {
    state = layout;
    ref.read(reportRepositoryProvider).saveLayout(layout);
  }
}

/// Detailed tab rows, 50 per page with "load more".
final reportRowsProvider = AsyncNotifierProvider.autoDispose<ReportRows, ReportPage>(ReportRows.new);

class ReportRows extends AsyncNotifier<ReportPage> {
  bool _loadingMore = false;

  @override
  Future<ReportPage> build() async {
    ref.watch(visitsRevisionProvider);
    ref.watch(reportFilterProvider);
    // The layout is derived from the column list; once that has loaded, the layout is known.
    await ref.watch(reportColumnsProvider.future);
    ref.watch(reportLayoutProvider);
    return _fetch(1);
  }

  Future<ReportPage> _fetch(int page) async => (await ref.read(getReportPageProvider)((
    filter: ref.read(reportFilterProvider),
    layout: ref.read(reportLayoutProvider)!,
    page: page,
  ))).getOrThrow();

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await _fetch(current.page + 1);
      if (!ref.mounted) return;
      state = AsyncData(
        ReportPage(
          rows: [...current.rows, ...next.rows],
          totals: next.totals,
          page: next.page,
          lastPage: next.lastPage,
        ),
      );
    } catch (_) {
      // Keep what is shown; the user can pull to refresh.
    } finally {
      _loadingMore = false;
    }
  }
}

final reportGroupProvider = NotifierProvider.autoDispose<ReportGroupNotifier, ReportGroup>(ReportGroupNotifier.new);

class ReportGroupNotifier extends Notifier<ReportGroup> {
  @override
  ReportGroup build() => ReportGroup.visitType;

  void set(ReportGroup g) => state = g;
}

final reportSummaryProvider = FutureProvider.autoDispose<List<SummaryRow>>((ref) async {
  ref.watch(visitsRevisionProvider);
  final filter = ref.watch(reportFilterProvider);
  final group = ref.watch(reportGroupProvider);
  return (await ref.watch(getReportSummaryProvider)((filter: filter, group: group))).getOrThrow();
});

/// Saved reports on this device.
final reportPresetsProvider = NotifierProvider.autoDispose<ReportPresetsNotifier, List<ReportPreset>>(
  ReportPresetsNotifier.new,
);

class ReportPresetsNotifier extends Notifier<List<ReportPreset>> {
  @override
  List<ReportPreset> build() => ref.read(reportRepositoryProvider).presets();

  /// Saves the current columns + filters (not dates) under [name], replacing one with the same name.
  void saveCurrent(String name) {
    final layout = ref.read(reportLayoutProvider);
    if (layout == null) return;
    final preset = ReportPreset(
      name: name,
      layout: layout,
      filter: ref.read(reportFilterProvider).withDates(null, null),
    );
    _store([...state.where((p) => p.name != name), preset]);
  }

  /// Applies a saved report, keeping the current date range.
  void apply(ReportPreset p) {
    final current = ref.read(reportFilterProvider);
    final known = {...?ref.read(reportColumnsProvider).value?.map((c) => c.key)};
    ref.read(reportFilterProvider.notifier).set(p.filter.withDates(current.from, current.to));
    ref
        .read(reportLayoutProvider.notifier)
        .set(p.layout.copyWith(columns: p.layout.columns.where(known.contains).toList()));
  }

  void delete(ReportPreset p) => _store(state.where((x) => x != p).toList());

  void _store(List<ReportPreset> list) {
    state = list;
    ref.read(reportRepositoryProvider).savePresets(list);
  }
}
