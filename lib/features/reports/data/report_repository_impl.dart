import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/guard.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/json_utils.dart';
import '../domain/report_entities.dart';
import '../domain/report_repository.dart';

final _day = DateFormat('yyyy-MM-dd');

class ReportRemoteDataSource {
  const ReportRemoteDataSource(this._api);

  final ApiClient _api;

  /// Query parameters of `VisitController::filters()`.
  static Map<String, dynamic> filterQuery(ReportFilter f) => {
    if (f.from != null) 'from': _day.format(f.from!),
    if (f.to != null) 'to': _day.format(f.to!),
    if (f.statuses.isNotEmpty) 'status': f.statuses.map((s) => s.value).join(','),
    if (f.types.isNotEmpty) 'visit_type': f.types.map((t) => t.value).join(','),
    if (f.methods.isNotEmpty) 'checkin_method': f.methods.map((m) => m.value).join(','),
    if ((f.q ?? '').trim().isNotEmpty) 'q': f.q!.trim(),
    'host_employee_id': ?f.hostId,
    'department_id': ?f.departmentId,
    'branch_id': ?f.branchId,
    if (f.hasGoods) 'has_goods': 1,
    for (final e in f.text.entries)
      if (e.value.trim().isNotEmpty) 'f_${e.key}': e.value.trim(),
  };

  static Map<String, dynamic> _layoutQuery(ReportLayout l) => {
    'columns': l.columns.join(','),
    'sort': l.sort,
    'dir': l.descending ? 'desc' : 'asc',
  };

  Future<List<ReportColumn>> columns() async {
    final d = await _api.get('reports/columns') as Map<String, dynamic>;
    return [
      for (final c in (d['columns'] as List).cast<Map<String, dynamic>>())
        ReportColumn(
          key: c['key'] as String,
          label: c['label']?.toString() ?? c['key'] as String,
          isDefault: c['default'] == true,
          sortable: c['sortable'] == true,
        ),
    ];
  }

  Future<ReportPage> visits(ReportFilter f, ReportLayout l, int page, int perPage) async {
    final (rows, meta) = await _api.getPaged(
      'reports/visits',
      query: {...filterQuery(f), ..._layoutQuery(l), 'page': page, 'per_page': perPage},
    );
    final t = (meta['totals'] as Map<String, dynamic>?) ?? const {};
    return ReportPage(
      rows: [
        for (final r in rows.cast<Map<String, dynamic>>())
          ReportRow(
            id: parseInt(r['id'])!,
            values: {
              for (final e in r.entries)
                if (e.key != 'id') e.key: e.value?.toString(),
            },
          ),
      ],
      totals: ReportTotals(
        visits: parseInt(t['visits']) ?? 0,
        persons: parseInt(t['persons']) ?? 0,
        inside: parseInt(t['inside']) ?? 0,
        withGoods: parseInt(t['with_goods']) ?? 0,
      ),
      page: parseInt(meta['page']) ?? page,
      lastPage: parseInt(meta['last_page']) ?? page,
    );
  }

  Future<List<SummaryRow>> summary(ReportFilter f, ReportGroup group) async {
    final d = await _api.get('reports/summary', query: {...filterQuery(f), 'group_by': group.value}) as Map;
    return [
      for (final r in (d['rows'] as List? ?? const []).cast<Map<String, dynamic>>())
        SummaryRow(
          label: r['label']?.toString() ?? '-',
          visits: parseInt(r['visits']) ?? 0,
          persons: parseInt(r['persons']) ?? 0,
          completed: parseInt(r['completed']) ?? 0,
          avgMinutes: parseInt(r['avg_minutes']),
        ),
    ];
  }

  Future<ExportFile> export(ReportFilter f, ReportLayout l, ExportFormat format) async {
    final (bytes, name) = await _api.download(
      'reports/visits',
      query: {...filterQuery(f), ..._layoutQuery(l), 'format': format.name},
    );
    final ext = format == ExportFormat.csv ? 'csv' : 'xls';
    return ExportFile(bytes: bytes, filename: name ?? 'visit-report.$ext');
  }

  Future<List<NamedOption>> options(String path) async {
    final rows = await _api.get(path) as List;
    return [
      for (final r in rows.cast<Map<String, dynamic>>()) NamedOption(parseInt(r['id'])!, r['name']?.toString() ?? ''),
    ];
  }
}

/// Column layout and saved reports, kept on this device (web: localStorage).
class ReportLocalDataSource {
  const ReportLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const _layoutKey = 'report_layout';
  static const _presetsKey = 'report_presets';

  ReportLayout? layout() {
    final raw = _prefs.getString(_layoutKey);
    if (raw == null) return null;
    try {
      return _layoutFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLayout(ReportLayout l) => _prefs.setString(_layoutKey, jsonEncode(_layoutToJson(l)));

  List<ReportPreset> presets() {
    final raw = _prefs.getString(_presetsKey);
    if (raw == null) return const [];
    try {
      return [
        for (final p in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          ReportPreset(
            name: p['name'] as String,
            layout: _layoutFromJson(p['layout'] as Map<String, dynamic>),
            filter: ReportFilter.fromJson(p['filter'] as Map<String, dynamic>),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePresets(List<ReportPreset> list) => _prefs.setString(
    _presetsKey,
    jsonEncode([
      for (final p in list)
        {'name': p.name, 'layout': _layoutToJson(p.layout), 'filter': p.filter.toJson(withDates: false)},
    ]),
  );

  static Map<String, dynamic> _layoutToJson(ReportLayout l) => {
    'columns': l.columns,
    'sort': l.sort,
    'desc': l.descending,
  };

  static ReportLayout _layoutFromJson(Map<String, dynamic> j) => ReportLayout(
    columns: (j['columns'] as List).cast<String>(),
    sort: j['sort'] as String? ?? 'check_in_at',
    descending: j['desc'] != false,
  );
}

class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl(this._remote, this._local);

  final ReportRemoteDataSource _remote;
  final ReportLocalDataSource _local;

  @override
  Future<Result<List<ReportColumn>>> columns() => guard(_remote.columns);

  @override
  Future<Result<ReportPage>> visits(ReportFilter filter, ReportLayout layout, {int page = 1, int perPage = 50}) =>
      guard(() => _remote.visits(filter, layout, page, perPage));

  @override
  Future<Result<List<SummaryRow>>> summary(ReportFilter filter, ReportGroup group) =>
      guard(() => _remote.summary(filter, group));

  @override
  Future<Result<ExportFile>> export(ReportFilter filter, ReportLayout layout, ExportFormat format) =>
      guard(() => _remote.export(filter, layout, format));

  @override
  Future<Result<List<NamedOption>>> departments() => guard(() => _remote.options('departments'));

  @override
  Future<Result<List<NamedOption>>> branches() => guard(() => _remote.options('branches'));

  @override
  ReportLayout? savedLayout() => _local.layout();

  @override
  Future<void> saveLayout(ReportLayout layout) => _local.saveLayout(layout);

  @override
  List<ReportPreset> presets() => _local.presets();

  @override
  Future<void> savePresets(List<ReportPreset> presets) => _local.savePresets(presets);
}
