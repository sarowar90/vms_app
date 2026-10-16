import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../../core/error/failures.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../../domain/master_entities.dart';
import '../master_providers.dart';

/// What a list row shows.
typedef MasterTileContent = ({IconData icon, String title, String? code, List<String> lines});

/// Generic setup list (web: `crud.js` + `crud-table.php`): search, count,
/// add / edit in a bottom-sheet form, delete with confirmation.
class MasterListPage<T extends MasterItem> extends ConsumerStatefulWidget {
  const MasterListPage({
    super.key,
    required this.title,
    required this.list,
    required this.mutation,
    required this.tile,
    required this.form,
  });

  final String title;
  final ProviderListenable<AsyncValue<List<T>>> list;
  final ProviderListenable<MasterMutation<T>> mutation;
  final MasterTileContent Function(T item) tile;

  /// The add (`null`) / edit form shown in a bottom sheet. It pops with a success message.
  final Widget Function(T? item) form;

  @override
  ConsumerState<MasterListPage<T>> createState() => _MasterListPageState<T>();
}

class _MasterListPageState<T extends MasterItem> extends ConsumerState<MasterListPage<T>> {
  String _query = '';

  Future<void> _openForm(T? item) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => widget.form(item),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _delete(T item) async {
    final ok = await confirmDelete(context, 'Delete "${item.name}"?\nAre you sure you want to delete this record?');
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final failure = await ref.read(widget.mutation).delete(item.id!);
    // The server refuses when other records still use it (e.g. a branch with departments).
    messenger.showSnackBar(SnackBar(content: Text(failure?.message ?? 'Deleted successfully')));
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(widget.list);
    // Keep the (auto-dispose) save/delete notifier alive while this page is open.
    ref.watch(widget.mutation);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(list.value == null ? widget.title : '${widget.title} (${fmtNumber(list.value!.length)})'),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Add New'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.read(mastersRevisionProvider.notifier).bump(),
              child: AsyncValueView(
                value: list,
                onRetry: () => ref.read(mastersRevisionProvider.notifier).bump(),
                data: (all) {
                  final items = all
                      .where((i) => _query.isEmpty || i.searchText.toLowerCase().contains(_query))
                      .toList();
                  if (items.isEmpty) {
                    return ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: Text('No records found')),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final c = widget.tile(item);
                      return ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(c.icon, color: theme.colorScheme.primary),
                        ),
                        title: Row(
                          children: [
                            if (c.code != null) ...[
                              Text(c.code!, style: theme.textTheme.labelMedium?.copyWith(fontFamily: 'monospace')),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                c.title,
                                style: const TextStyle(fontWeight: .w600),
                                overflow: .ellipsis,
                              ),
                            ),
                            _ActiveBadge(item.active),
                          ],
                        ),
                        subtitle: c.lines.isEmpty ? null : Text(c.lines.join('\n'), style: theme.textTheme.bodySmall),
                        isThreeLine: c.lines.length > 1,
                        onTap: () => _openForm(item),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          onPressed: () => _delete(item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge(this.active);

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2E9E6A) : const Color(0xFF6C757D);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(color: color, fontSize: 11, fontWeight: .w600),
      ),
    );
  }
}

/// Shared frame of the add/edit sheets: title, fields, error, Save.
class MasterFormSheet extends StatelessWidget {
  const MasterFormSheet({
    super.key,
    required this.formKey,
    required this.title,
    required this.children,
    required this.onSave,
    required this.saving,
    this.failure,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool saving;
  final Object? failure;

  @override
  Widget build(BuildContext context) {
    final f = failure;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            spacing: 14,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              ...children,
              // Errors without a field (e.g. "Branch not found").
              if (f is Failure && (f is! ServerFailure || f.errors == null))
                Text(f.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Field error text from a failed save.
String? masterFieldError(Object? failure, String field) => failure is ServerFailure ? failure.fieldError(field) : null;

/// Active / Inactive switch used by all three forms.
class ActiveSwitch extends StatelessWidget {
  const ActiveSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Status'),
    subtitle: Text(value ? 'Active' : 'Inactive'),
    value: value,
    onChanged: onChanged,
  );
}
