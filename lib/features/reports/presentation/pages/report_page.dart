import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../../shared/data/json_utils.dart';
import '../../../../shared/presentation/widgets/status_chip.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import '../../../visits/presentation/widgets/visit_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../../../visits/presentation/providers/visit_providers.dart';
import '../../../visits/presentation/widgets/visit_actions_sheet.dart';
import '../../domain/report_entities.dart';
import '../../domain/report_use_cases.dart';
import '../report_providers.dart';
import '../widgets/report_cells.dart';
import '../widgets/report_filter_sheet.dart';
import '../widgets/report_layout_sheets.dart';

/// Visitor Report (web: `reports.php`): filters, totals, Detailed and Summary tabs,
/// column chooser, saved reports and Excel/CSV export.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  bool _exporting = false;

  /// Downloads the file and opens the share sheet (save to Files/Drive, send by email…).
  Future<void> _export(ExportFormat format) async {
    final layout = ref.read(reportLayoutProvider);
    if (layout == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    final result = await ref.read(exportReportProvider)((
      filter: ref.read(reportFilterProvider),
      layout: layout,
      format: format,
    ));
    if (!mounted) return;
    setState(() => _exporting = false);
    switch (result) {
      case Success(:final value):
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${value.filename}');
        await file.writeAsBytes(value.bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: format == ExportFormat.csv ? 'text/csv' : 'application/vnd.ms-excel')],
            subject: 'Visitor Report',
          ),
        );
      case Error(:final failure):
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final columns = ref.watch(reportColumnsProvider).value;
    final layout = ref.watch(reportLayoutProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visitor Report'),
          actions: [
            IconButton(
              tooltip: 'Saved Reports',
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: () => SavedReportsSheet.open(context),
            ),
            IconButton(
              tooltip: 'Columns',
              icon: const Icon(Icons.view_column_outlined),
              onPressed: columns == null || layout == null
                  ? null
                  : () => ColumnChooserPage.open(context, columns, layout),
            ),
            if (user?.can('reports.export') ?? false)
              _exporting
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : PopupMenuButton<ExportFormat>(
                      tooltip: 'Export',
                      icon: const Icon(Icons.ios_share),
                      onSelected: _export,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: ExportFormat.excel,
                          child: ListTile(leading: Icon(Icons.grid_on), title: Text('Excel')),
                        ),
                        PopupMenuItem(
                          value: ExportFormat.csv,
                          child: ListTile(leading: Icon(Icons.description_outlined), title: Text('CSV')),
                        ),
                      ],
                    ),
          ],
        ),
        drawer: const AppDrawer(),
        // Dates and totals scroll away with the results; the tabs stay pinned.
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            const SliverToBoxAdapter(child: _FilterBar()),
            const SliverToBoxAdapter(child: _Totals()),
            SliverPersistentHeader(pinned: true, delegate: _PinnedTabs(Theme.of(context).colorScheme.surface)),
          ],
          body: const TabBarView(children: [_DetailedTab(), _SummaryTab()]),
        ),
      ),
    );
  }
}

/// Detailed / Summary tabs, pinned under the app bar while results scroll.
class _PinnedTabs extends SliverPersistentHeaderDelegate {
  _PinnedTabs(this.background);

  final Color background;

  static const _tabBar = TabBar(
    tabs: [
      Tab(
        height: 48,
        child: Row(
          mainAxisSize: .min,
          spacing: 6,
          children: [Icon(Icons.view_agenda_outlined, size: 18), Text('Detailed')],
        ),
      ),
      Tab(
        height: 48,
        child: Row(
          mainAxisSize: .min,
          spacing: 6,
          children: [Icon(Icons.pie_chart_outline, size: 18), Text('Summary')],
        ),
      ),
    ],
  );

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: background, elevation: overlapsContent ? 2 : 0, child: _tabBar);

  @override
  bool shouldRebuild(_PinnedTabs old) => old.background != background;
}

/// Date range shortcuts + the current range + Filters button.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final range = filter.from == null && filter.to == null
        ? 'All dates'
        : '${filter.from == null ? '…' : fmtDate(filter.from)} — ${filter.to == null ? '…' : fmtDate(filter.to)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(range, style: Theme.of(context).textTheme.titleSmall)),
              TextButton.icon(
                onPressed: () => ReportFilterSheet.open(context),
                icon: Badge(
                  isLabelVisible: filter.activeCount > 0,
                  label: Text('${filter.activeCount}'),
                  child: const Icon(Icons.tune),
                ),
                label: const Text('Filters'),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                for (final r in ReportRange.values)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(r.label),
                    onPressed: () => ref.read(reportFilterProvider.notifier).range(r),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends ConsumerWidget {
  const _Totals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(reportRowsProvider).value?.totals;
    final items = [
      ('Total Visits', t?.visits, Icons.checklist, const Color(0xFF1D5FC1)),
      ('Total Persons', t?.persons, Icons.groups_outlined, const Color(0xFF2E9E6A)),
      ('Inside Now', t?.inside, Icons.meeting_room_outlined, const Color(0xFF0B7D93)),
      ('With Goods', t?.withGoods, Icons.inventory_2_outlined, const Color(0xFFF4A300)),
    ];
    // Small tinted tiles: number first, label under it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        spacing: 8,
        children: [
          for (final (label, value, icon, color) in items)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  spacing: 2,
                  children: [
                    Icon(icon, color: color, size: 18),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value == null ? '–' : fmtNumber(value),
                        style: TextStyle(fontWeight: .w800, fontSize: 18, color: color),
                      ),
                    ),
                    Text(
                      label,
                      textAlign: .center,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailedTab extends ConsumerWidget {
  const _DetailedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(reportRowsProvider);
    final layout = ref.watch(reportLayoutProvider);
    final columns = ref.watch(reportColumnsProvider).value ?? const [];
    final labels = {for (final c in columns) c.key: c.label};

    return Column(
      children: [
        if (layout != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Text('Sort by', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: columns.any((c) => c.key == layout.sort && c.sortable) ? layout.sort : null,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final c in columns.where((c) => c.sortable))
                        DropdownMenuItem(
                          value: c.key,
                          child: Text(c.label, overflow: .ellipsis),
                        ),
                    ],
                    onChanged: (v) => ref.read(reportLayoutProvider.notifier).set(layout.copyWith(sort: v)),
                  ),
                ),
                IconButton(
                  tooltip: layout.descending ? 'Descending' : 'Ascending',
                  icon: Icon(layout.descending ? Icons.arrow_downward : Icons.arrow_upward),
                  onPressed: () =>
                      ref.read(reportLayoutProvider.notifier).set(layout.copyWith(descending: !layout.descending)),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(reportRowsProvider.future).then((_) {}, onError: (_) {}),
            child: AsyncValueView(
              value: rows,
              onRetry: () {
                ref.invalidate(reportColumnsProvider);
                ref.invalidate(reportRowsProvider);
              },
              data: (page) {
                if (page.rows.isEmpty) {
                  return ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: Text('No records found')),
                      ),
                    ],
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 400) ref.read(reportRowsProvider.notifier).loadMore();
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: page.rows.length + (page.hasMore ? 1 : 0),
                    itemBuilder: (context, i) => i == page.rows.length
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _RowCard(row: page.rows[i], columns: layout?.columns ?? const [], labels: labels),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Columns the compact card shows in its header / icon lines; any other chosen
/// column goes under "More details".
const _cardColumns = {
  'visitor_name',
  'status',
  'visitor_designation',
  'visitor_company',
  'purpose',
  'visit_no',
  'check_in_at',
  'check_out_at',
  'duration',
  'host_name',
  'department_name',
  'visit_type',
  'persons_count',
  'checkin_method',
  'carrying_goods',
  'visitor_phone',
};

/// One report row as a compact card (a wide table does not fit a phone):
/// name + status, the key facts as icon lines, the rest behind "More details".
/// Only columns chosen in the column chooser are shown.
class _RowCard extends ConsumerStatefulWidget {
  const _RowCard({required this.row, required this.columns, required this.labels});

  final ReportRow row;
  final List<String> columns;
  final Map<String, String> labels;

  @override
  ConsumerState<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends ConsumerState<_RowCard> {
  bool _expanded = false;

  Future<void> _openVisit() async {
    final result = await ref.read(getVisitProvider)(widget.row.id);
    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        showVisitActionsSheet(context, value);
      case Error(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = widget.row.values;
    final chosen = widget.columns.toSet();
    // A chosen column with a value.
    String? get(String key) => chosen.contains(key) && (v[key] ?? '').isNotEmpty ? v[key] : null;
    String? shown(String key) => get(key) == null ? null : formatReportCell(key, v[key]);

    final name = get('visitor_name') ?? get('visit_no') ?? '#${widget.row.id}';
    final status = get('status') == null ? null : VisitStatus.fromValue(v['status']);
    final subtitle = [?get('visitor_designation'), ?get('visitor_company')].join(' · ');
    final type = VisitType.fromValue(get('visit_type'));
    final method = CheckinMethod.fromValue(get('checkin_method'));
    final inAt = get('check_in_at') == null ? null : parseDateTime(v['check_in_at']);
    final outAt = get('check_out_at') == null ? null : parseDateTime(v['check_out_at']);

    final timeLine = switch ((inAt, outAt)) {
      (final i?, final o?) => '${fmtDate(i)}  ${fmtTime(i)} → ${fmtTime(o)}',
      (final i?, null) => '${fmtDate(i)}  ${fmtTime(i)} → ${status == VisitStatus.checkedIn ? 'inside' : '–'}',
      (null, final o?) => 'Out ${fmtDateTime(o)}',
      _ => null,
    };
    final host = [?get('host_name'), ?get('department_name')].join(' · ');
    final persons = int.tryParse(get('persons_count') ?? '');

    final more = [
      for (final c in widget.columns)
        if (!_cardColumns.contains(c) && (v[c] ?? '').isNotEmpty) (widget.labels[c] ?? c, formatReportCell(c, v[c])),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openVisit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                children: [
                  VisitorAvatar(name: name, radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: .w700, fontSize: 15),
                          overflow: .ellipsis,
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            overflow: .ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ?(status == null ? null : StatusChip(status)),
                ],
              ),
              if (get('purpose') case final p?) ...[
                const SizedBox(height: 8),
                Text(p, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (timeLine != null) _ReportMeta(Icons.schedule, timeLine),
                  if (shown('duration') case final d?) _ReportMeta(Icons.hourglass_bottom, d),
                  if (host.isNotEmpty) _ReportMeta(Icons.person_outline, host),
                  if (type != null) _ReportMeta(visitTypeIcons[type] ?? Icons.category_outlined, type.label),
                  if (persons != null)
                    _ReportMeta(Icons.groups_outlined, '$persons ${persons == 1 ? 'person' : 'persons'}'),
                  if (method != null) _ReportMeta(method.icon, method.label),
                  if (get('carrying_goods') case final g?) _ReportMeta(Icons.inventory_2_outlined, g),
                  if (get('visitor_phone') case final ph?) _ReportMeta(Icons.phone_outlined, ph),
                  if (get('visit_no') case final no? when name != no) _ReportMeta(Icons.tag, no),
                ],
              ),
              if (more.isEmpty)
                const SizedBox(height: 8)
              else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                    label: Text(_expanded ? 'Less' : 'More details (${more.length})'),
                  ),
                ),
                if (_expanded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      spacing: 4,
                      children: [
                        for (final (label, value) in more)
                          Row(
                            crossAxisAlignment: .start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  label,
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                ),
                              ),
                              Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportMeta extends StatelessWidget {
  const _ReportMeta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: .min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(reportGroupProvider);
    final summary = ref.watch(reportSummaryProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Text('Group by', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<ReportGroup>(
                  isExpanded: true,
                  value: group,
                  underline: const SizedBox.shrink(),
                  items: [for (final g in ReportGroup.values) DropdownMenuItem(value: g, child: Text(g.label))],
                  onChanged: (g) => ref.read(reportGroupProvider.notifier).set(g ?? ReportGroup.visitType),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(reportSummaryProvider.future).then((_) {}, onError: (_) {}),
            child: AsyncValueView(
              value: summary,
              onRetry: () => ref.invalidate(reportSummaryProvider),
              data: (rows) {
                if (rows.isEmpty) {
                  return ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: Text('No records found')),
                      ),
                    ],
                  );
                }
                final total = rows.fold<int>(0, (s, r) => s + r.visits);
                final persons = rows.fold<int>(0, (s, r) => s + r.persons);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    for (final r in rows) _SummaryTile(group: group, row: r, total: total),
                    const Divider(),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Total', style: TextStyle(fontWeight: .w700)),
                        ),
                        Text(
                          '${fmtNumber(total)} visits · ${fmtNumber(persons)} persons',
                          style: const TextStyle(fontWeight: .w700),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.group, required this.row, required this.total});

  final ReportGroup group;
  final SummaryRow row;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = total == 0 ? 0.0 : row.visits / total;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 4,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatGroupLabel(group, row.label),
                  style: const TextStyle(fontWeight: .w600),
                  overflow: .ellipsis,
                ),
              ),
              Text('${fmtNumber(row.visits)}  ·  ${(share * 100).round()}%'),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: share, minHeight: 6),
          ),
          Text(
            [
              '${fmtNumber(row.persons)} persons',
              '${fmtNumber(row.completed)} completed',
              if (row.avgMinutes != null) 'avg ${fmtDuration(row.avgMinutes!)}',
            ].join(' · '),
            style: muted,
          ),
        ],
      ),
    );
  }
}
