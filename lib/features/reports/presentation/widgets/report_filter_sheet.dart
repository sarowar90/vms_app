import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../visits/presentation/providers/visit_providers.dart';
import '../../domain/report_entities.dart';
import '../report_providers.dart';

/// All report filters (web: the filter form + "Advanced filters").
class ReportFilterSheet extends ConsumerStatefulWidget {
  const ReportFilterSheet({super.key});

  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const ReportFilterSheet(),
  );

  @override
  ConsumerState<ReportFilterSheet> createState() => _ReportFilterSheetState();
}

class _ReportFilterSheetState extends ConsumerState<ReportFilterSheet> {
  late final ReportFilter _initial = ref.read(reportFilterProvider);
  late DateTime? _from = _initial.from;
  late DateTime? _to = _initial.to;
  late final Set<VisitStatus> _statuses = {..._initial.statuses};
  late final Set<VisitType> _types = {..._initial.types};
  late final Set<CheckinMethod> _methods = {..._initial.methods};
  late final _q = TextEditingController(text: _initial.q);
  late int? _hostId = _initial.hostId;
  late int? _departmentId = _initial.departmentId;
  late int? _branchId = _initial.branchId;
  late bool _hasGoods = _initial.hasGoods;
  late final Map<String, TextEditingController> _text = {
    for (final k in reportTextFilters.keys) k: TextEditingController(text: _initial.text[k]),
  };

  @override
  void dispose() {
    _q.dispose();
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  void _apply() {
    ref
        .read(reportFilterProvider.notifier)
        .set(
          ReportFilter(
            from: _from,
            to: _to,
            statuses: _statuses,
            types: _types,
            methods: _methods,
            q: _q.text.trim().isEmpty ? null : _q.text.trim(),
            hostId: _hostId,
            departmentId: _departmentId,
            branchId: _branchId,
            hasGoods: _hasGoods,
            text: {
              for (final e in _text.entries)
                if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
            },
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(authProvider).value?.can('visits.view_all') ?? false;
    final theme = Theme.of(context);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(title, style: theme.textTheme.labelLarge),
    );

    Widget chips<T>(Iterable<T> values, Set<T> selected, String Function(T) label) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          FilterChip(
            label: Text(label(v)),
            selected: selected.contains(v),
            onSelected: (on) => setState(() => on ? selected.add(v) : selected.remove(v)),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: .min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                Text('Filters', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: _DateBox(label: 'From', value: _from, onTap: () => _pickDate(true)),
                    ),
                    Expanded(
                      child: _DateBox(label: 'To', value: _to, onTap: () => _pickDate(false)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    hintText: 'Name, mobile, company, visit no...',
                    border: OutlineInputBorder(),
                  ),
                ),
                section('Visitor Status'),
                chips(VisitStatus.values, _statuses, (s) => s.label),
                section('Visit Type'),
                chips(VisitType.values, _types, (t) => t.label),
                section('Check-in Method'),
                chips(CheckinMethod.values, _methods, (m) => m.label),
                if (staff) ...[
                  const SizedBox(height: 12),
                  _OptionDropdown(
                    label: 'Host',
                    value: _hostId,
                    options: ref.watch(hostsProvider).value?.map((h) => NamedOption(h.id, h.name)).toList(),
                    onChanged: (v) => _hostId = v,
                  ),
                  const SizedBox(height: 12),
                  _OptionDropdown(
                    label: 'Department',
                    value: _departmentId,
                    options: ref.watch(reportDepartmentsProvider).value,
                    onChanged: (v) => _departmentId = v,
                  ),
                  const SizedBox(height: 12),
                  _OptionDropdown(
                    label: 'Branch',
                    value: _branchId,
                    options: ref.watch(reportBranchesProvider).value,
                    onChanged: (v) => _branchId = v,
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Only with carrying goods'),
                  value: _hasGoods,
                  onChanged: (v) => setState(() => _hasGoods = v),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced filters'),
                  initiallyExpanded: _initial.text.isNotEmpty,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final e in reportTextFilters.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _text[e.key],
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: e.value,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(reportFilterProvider.notifier).reset();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.filter_alt),
                      label: const Text('Generate'),
                    ),
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

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.event, size: 20),
      ),
      child: Text(value == null ? 'Any' : fmtDate(value)),
    ),
  );
}

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final int? value;
  final List<NamedOption>? options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final list = options ?? const <NamedOption>[];
    return DropdownButtonFormField<int?>(
      // Rebuild once the options arrive.
      key: ValueKey('$label-${list.length}'),
      initialValue: list.any((o) => o.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        const DropdownMenuItem(value: null, child: Text('All')),
        for (final o in list)
          DropdownMenuItem(
            value: o.id,
            child: Text(o.name, overflow: .ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
