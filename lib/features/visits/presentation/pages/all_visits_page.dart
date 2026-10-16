import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../../domain/entities/visit_entities.dart';
import '../providers/all_visits_providers.dart';
import '../providers/visit_providers.dart';
import '../widgets/visit_tile.dart';
import 'visit_form_page.dart';

/// All Visits (web: `visits.php`): search, status chips, type/date filters, paged list.
/// Employees without `visits.view_all` only get their own visits (the server scopes it).
class AllVisitsPage extends ConsumerStatefulWidget {
  const AllVisitsPage({super.key, this.initialStatus});

  /// From `?status=` (e.g. dashboard links).
  final VisitStatus? initialStatus;

  @override
  ConsumerState<AllVisitsPage> createState() => _AllVisitsPageState();
}

class _AllVisitsPageState extends ConsumerState<AllVisitsPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus case final s?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(allVisitsFilterProvider.notifier).setStatus(s));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() {}); // show/hide the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.read(allVisitsFilterProvider.notifier).setSearch(value);
    });
  }

  Future<void> _new() async {
    final message = await VisitFormPage.open(context);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(allVisitsFilterProvider);
    final list = ref.watch(visitListProvider(filter));
    final canCreate = ref.watch(authProvider).value?.can('visits.preregister') ?? false;
    final advanced = filter.visitType != null || filter.from != null || filter.to != null;

    return Scaffold(
      appBar: AppBar(title: const Text('All Visits')),
      drawer: const AppDrawer(),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _new,
              icon: const Icon(Icons.event_available),
              label: const Text('Pre-register'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Name, mobile, company, visit no...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                ref.read(allVisitsFilterProvider.notifier).setSearch('');
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Filters',
                  onPressed: () => _showFilters(context, ref, filter),
                  icon: Badge(isLabelVisible: advanced, child: const Icon(Icons.tune)),
                ),
              ],
            ),
          ),
          const _StatusChips(),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(visitListProvider(filter).future).then((_) {}, onError: (_) {}),
              child: AsyncValueView(
                value: list,
                onRetry: () => ref.invalidate(visitListProvider(filter)),
                data: (page) {
                  if (page.items.isEmpty) {
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
                      if (n.metrics.extentAfter < 300) ref.read(visitListProvider(filter).notifier).loadMore();
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: page.items.length + 1,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i < page.items.length) return VisitTile(page.items[i]);
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: page.hasMore
                                ? const CircularProgressIndicator()
                                : Text(
                                    '${fmtNumber(page.total)} visits',
                                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                                  ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters(BuildContext context, WidgetRef ref, VisitQuery current) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(current: current),
  );
}

class _StatusChips extends ConsumerWidget {
  const _StatusChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(allVisitsFilterProvider).statuses.firstOrNull;
    final counts = ref.watch(allVisitsCountsProvider).value;
    final total = counts?.values.fold(0, (a, b) => a + b);

    Widget chip(VisitStatus? status, String label, int? count) {
      final color = status?.color ?? Theme.of(context).colorScheme.primary;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected == status,
          showCheckmark: false,
          avatar: CircleAvatar(radius: 4, backgroundColor: color),
          label: Text(count == null ? label : '$label  ${fmtNumber(count)}'),
          onSelected: (_) => ref.read(allVisitsFilterProvider.notifier).setStatus(status),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          chip(null, 'All', total),
          for (final s in VisitStatus.values) chip(s, s.label, counts == null ? null : (counts[s] ?? 0)),
        ],
      ),
    );
  }
}

/// Visit type + date range, like the web filter bar.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.current});

  final VisitQuery current;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late VisitType? _type = widget.current.visitType;
  late DateTimeRange? _range = widget.current.from == null && widget.current.to == null
      ? null
      : DateTimeRange(start: widget.current.from ?? widget.current.to!, end: widget.current.to ?? widget.current.from!);

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _quick(int days) {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(
      () => _range = DateTimeRange(
        start: today.subtract(Duration(days: days)),
        end: today,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 14,
        children: [
          Text('Filters', style: Theme.of(context).textTheme.titleMedium),
          DropdownButtonFormField<VisitType?>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Visit Type', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              for (final t in VisitType.values) DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => _type = v,
          ),
          InkWell(
            onTap: _pickRange,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                border: const OutlineInputBorder(),
                suffixIcon: _range == null
                    ? const Icon(Icons.date_range)
                    : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _range = null)),
              ),
              child: Text(_range == null ? 'Any date' : '${fmtDate(_range!.start)} – ${fmtDate(_range!.end)}'),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(label: const Text('Today'), onPressed: () => _quick(0)),
              ActionChip(label: const Text('Last 7 days'), onPressed: () => _quick(6)),
              ActionChip(label: const Text('Last 30 days'), onPressed: () => _quick(29)),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(allVisitsFilterProvider.notifier).setAdvanced();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Reset'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(allVisitsFilterProvider.notifier)
                        .setAdvanced(visitType: _type, from: _range?.start, to: _range?.end);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
