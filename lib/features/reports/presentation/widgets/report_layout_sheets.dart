import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/report_entities.dart';
import '../report_providers.dart';

/// Column chooser: tick columns and drag to reorder (web: "Columns" panel).
class ColumnChooserPage extends ConsumerStatefulWidget {
  const ColumnChooserPage({super.key, required this.columns, required this.layout});

  final List<ReportColumn> columns;
  final ReportLayout layout;

  static Future<void> open(BuildContext context, List<ReportColumn> columns, ReportLayout layout) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ColumnChooserPage(columns: columns, layout: layout),
        ),
      );

  @override
  ConsumerState<ColumnChooserPage> createState() => _ColumnChooserPageState();
}

class _ColumnChooserPageState extends ConsumerState<ColumnChooserPage> {
  // Selected columns first (in their order), then the rest.
  late final List<String> _order = [
    ...widget.layout.columns,
    for (final c in widget.columns)
      if (!widget.layout.columns.contains(c.key)) c.key,
  ];
  late final Set<String> _selected = {...widget.layout.columns};

  String _label(String key) => widget.columns.firstWhere((c) => c.key == key).label;

  void _apply() {
    final cols = _order.where(_selected.contains).toList();
    if (cols.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one column')));
      return;
    }
    ref.read(reportLayoutProvider.notifier).set(widget.layout.copyWith(columns: cols));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Columns'),
        actions: [TextButton(onPressed: _apply, child: const Text('Apply'))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Tick the columns to show and drag to change their order. Your choice is remembered on this device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('Select all'), onPressed: () => setState(() => _selected.addAll(_order))),
                ActionChip(label: const Text('Select none'), onPressed: () => setState(_selected.clear)),
                ActionChip(
                  label: const Text('Default'),
                  onPressed: () => setState(() {
                    _selected
                      ..clear()
                      ..addAll([
                        for (final c in widget.columns)
                          if (c.isDefault) c.key,
                      ]);
                  }),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _order.length,
              onReorderItem: (from, to) => setState(() => _order.insert(to, _order.removeAt(from))),
              itemBuilder: (context, i) {
                final key = _order[i];
                return CheckboxListTile(
                  key: ValueKey(key),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _selected.contains(key),
                  onChanged: (on) => setState(() => on == true ? _selected.add(key) : _selected.remove(key)),
                  title: Text(_label(key)),
                  secondary: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Saved reports: apply, delete, or save the current layout + filters (web: "Saved Reports").
class SavedReportsSheet extends ConsumerStatefulWidget {
  const SavedReportsSheet({super.key});

  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SavedReportsSheet(),
  );

  @override
  ConsumerState<SavedReportsSheet> createState() => _SavedReportsSheetState();
}

class _SavedReportsSheetState extends ConsumerState<SavedReportsSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(reportPresetsProvider);
    final messenger = ScaffoldMessenger.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text('Saved Reports', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (presets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No saved reports yet', textAlign: .center),
            )
          else
            for (final p in presets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmark_added_outlined),
                title: Text(p.name),
                subtitle: Text('${p.layout.columns.length} columns'),
                onTap: () {
                  ref.read(reportPresetsProvider.notifier).apply(p);
                  Navigator.of(context).pop();
                },
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  onPressed: () => ref.read(reportPresetsProvider.notifier).delete(p),
                ),
              ),
          const Divider(),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Report name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final name = _name.text.trim();
                  if (name.isEmpty) return;
                  ref.read(reportPresetsProvider.notifier).saveCurrent(name);
                  _name.clear();
                  messenger.showSnackBar(const SnackBar(content: Text('Report layout saved')));
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
