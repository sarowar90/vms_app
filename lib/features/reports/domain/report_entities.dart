import 'package:flutter/foundation.dart';

import '../../../shared/domain/entities/visit.dart';

/// A column the report can show (`GET /reports/columns`).
class ReportColumn {
  const ReportColumn({required this.key, required this.label, required this.isDefault, required this.sortable});

  final String key;
  final String label;
  final bool isDefault;
  final bool sortable;
}

/// Text filters of the "Advanced filters" section: key => label.
const reportTextFilters = {
  'visitor_name': 'Visitor Name',
  'visitor_phone': 'Mobile',
  'visitor_email': 'Email',
  'visitor_company': 'Company',
  'visitor_designation': 'Designation',
  'purpose': 'Purpose',
  'carrying_goods': 'Carrying Goods',
  'remarks': 'Remarks',
  'card_no': 'Card No',
  'vehicle_no': 'Vehicle No',
};

/// Report filters (web: the filter form). Value-equal so providers can key on it.
@immutable
class ReportFilter {
  const ReportFilter({
    this.from,
    this.to,
    this.statuses = const {},
    this.types = const {},
    this.methods = const {},
    this.q,
    this.hostId,
    this.departmentId,
    this.branchId,
    this.hasGoods = false,
    this.text = const {},
  });

  final DateTime? from;
  final DateTime? to;
  final Set<VisitStatus> statuses;
  final Set<VisitType> types;
  final Set<CheckinMethod> methods;
  final String? q;
  final int? hostId;
  final int? departmentId;
  final int? branchId;
  final bool hasGoods;

  /// Advanced text filters, keyed like [reportTextFilters].
  final Map<String, String> text;

  /// Number of filters set besides the date range (for a badge).
  int get activeCount =>
      (statuses.isNotEmpty ? 1 : 0) +
      (types.isNotEmpty ? 1 : 0) +
      (methods.isNotEmpty ? 1 : 0) +
      ((q ?? '').isNotEmpty ? 1 : 0) +
      (hostId != null ? 1 : 0) +
      (departmentId != null ? 1 : 0) +
      (branchId != null ? 1 : 0) +
      (hasGoods ? 1 : 0) +
      text.length;

  ReportFilter withDates(DateTime? from, DateTime? to) => ReportFilter(
    from: from,
    to: to,
    statuses: statuses,
    types: types,
    methods: methods,
    q: q,
    hostId: hostId,
    departmentId: departmentId,
    branchId: branchId,
    hasGoods: hasGoods,
    text: text,
  );

  /// Stored with saved reports (dates are left out so a saved report is date-independent).
  Map<String, dynamic> toJson({bool withDates = true}) => {
    if (withDates && from != null) 'from': from!.toIso8601String(),
    if (withDates && to != null) 'to': to!.toIso8601String(),
    'status': [for (final s in statuses) s.value],
    'visit_type': [for (final t in types) t.value],
    'checkin_method': [for (final m in methods) m.value],
    'q': ?q,
    'host_employee_id': ?hostId,
    'department_id': ?departmentId,
    'branch_id': ?branchId,
    'has_goods': hasGoods,
    'text': text,
  };

  factory ReportFilter.fromJson(Map<String, dynamic> j) => ReportFilter(
    from: j['from'] == null ? null : DateTime.tryParse(j['from'] as String),
    to: j['to'] == null ? null : DateTime.tryParse(j['to'] as String),
    statuses: {for (final s in (j['status'] as List? ?? const [])) VisitStatus.fromValue(s as String)},
    types: {for (final t in (j['visit_type'] as List? ?? const [])) ?VisitType.fromValue(t as String)},
    methods: {for (final m in (j['checkin_method'] as List? ?? const [])) ?CheckinMethod.fromValue(m as String)},
    q: j['q'] as String?,
    hostId: j['host_employee_id'] as int?,
    departmentId: j['department_id'] as int?,
    branchId: j['branch_id'] as int?,
    hasGoods: j['has_goods'] == true,
    text: (j['text'] as Map? ?? const {}).map((k, v) => MapEntry(k as String, v as String)),
  );

  @override
  bool operator ==(Object other) => other is ReportFilter && mapEquals(_key(other), _key(this));

  @override
  int get hashCode => Object.hashAll(_key(this).entries.map((e) => Object.hash(e.key, e.value.toString())));

  static Map<String, String> _key(ReportFilter f) =>
      f.toJson().map((k, v) => MapEntry(k, v is List ? (v.map((e) => '$e').toList()..sort()).join(',') : '$v'));
}

/// Chosen columns and sort order (web: column chooser, remembered per device).
@immutable
class ReportLayout {
  const ReportLayout({required this.columns, this.sort = 'check_in_at', this.descending = true});

  final List<String> columns;
  final String sort;
  final bool descending;

  ReportLayout copyWith({List<String>? columns, String? sort, bool? descending}) => ReportLayout(
    columns: columns ?? this.columns,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
  );

  @override
  bool operator ==(Object other) =>
      other is ReportLayout &&
      listEquals(other.columns, columns) &&
      other.sort == sort &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(Object.hashAll(columns), sort, descending);
}

/// A saved report: columns + filters + sort, without dates (web: "Saved Reports").
class ReportPreset {
  const ReportPreset({required this.name, required this.layout, required this.filter});

  final String name;
  final ReportLayout layout;
  final ReportFilter filter;
}

/// One report row: the visit id plus the chosen columns' raw values.
class ReportRow {
  const ReportRow({required this.id, required this.values});

  final int id;
  final Map<String, String?> values;
}

class ReportTotals {
  const ReportTotals({required this.visits, required this.persons, required this.inside, required this.withGoods});

  final int visits;
  final int persons;
  final int inside;
  final int withGoods;
}

class ReportPage {
  const ReportPage({required this.rows, required this.totals, required this.page, required this.lastPage});

  final List<ReportRow> rows;
  final ReportTotals totals;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

/// Summary tab "Group by" options.
enum ReportGroup {
  visitType('visit_type', 'Visit Type'),
  status('status', 'Visitor Status'),
  checkinMethod('checkin_method', 'Check-in Method'),
  host('host', 'Host'),
  department('department', 'Department'),
  branch('branch', 'Branch'),
  company('company', 'Company'),
  date('date', 'Date'),
  month('month', 'Month');

  const ReportGroup(this.value, this.label);

  final String value;
  final String label;
}

class SummaryRow {
  const SummaryRow({
    required this.label,
    required this.visits,
    required this.persons,
    required this.completed,
    this.avgMinutes,
  });

  /// Raw group value (e.g. `meeting`, `2026-10-15`, a host name).
  final String label;
  final int visits;
  final int persons;
  final int completed;
  final int? avgMinutes;
}

enum ExportFormat { excel, csv }

/// A downloaded export file.
class ExportFile {
  const ExportFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// id + name, for department / branch pickers.
class NamedOption {
  const NamedOption(this.id, this.name);

  final int id;
  final String name;
}
