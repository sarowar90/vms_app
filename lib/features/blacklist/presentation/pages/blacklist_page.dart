import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/domain/validators.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../../domain/blacklist_repository.dart';
import '../blacklist_providers.dart';

/// Blacklist (web: `blacklist.php`). Anyone with `blacklist.view` sees the list;
/// `blacklist.manage` can add, edit and remove.
class BlacklistPage extends ConsumerStatefulWidget {
  const BlacklistPage({super.key, this.prefill});

  /// From a visitor profile's "Add to Blacklist": opens the form pre-filled.
  final BlacklistInput? prefill;

  @override
  ConsumerState<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends ConsumerState<BlacklistPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(authProvider).value?.can('blacklist.manage') ?? false) _openForm(prefill: prefill);
      });
    }
  }

  Future<void> _openForm({BlacklistItem? item, BlacklistInput? prefill}) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BlacklistForm(item: item, prefill: prefill),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _delete(BlacklistItem item) async {
    final ok = await confirmDelete(
      context,
      'Remove ${item.name ?? item.phone ?? item.idNumber} from the blacklist?',
      okText: 'Remove',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = await ref.read(blacklistMutationProvider.notifier).delete(item.id);
    messenger.showSnackBar(
      SnackBar(content: Text(done ? 'Removed from blacklist' : '${ref.read(blacklistMutationProvider).error}')),
    );
  }

  bool _matches(BlacklistItem i) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [i.name, i.phone, i.idNumber, i.reason].any((s) => s != null && s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(blacklistProvider);
    // Keep the auto-dispose delete notifier alive while this page is open.
    ref.watch(blacklistMutationProvider);
    final canManage = ref.watch(authProvider).value?.can('blacklist.manage') ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(list.value == null ? 'Blacklist' : 'Blacklist (${fmtNumber(list.value!.length)})')),
      drawer: const AppDrawer(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add New'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
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
              onRefresh: () => ref.refresh(blacklistProvider.future).then((_) {}, onError: (_) {}),
              child: AsyncValueView(
                value: list,
                onRetry: () => ref.invalidate(blacklistProvider),
                data: (all) {
                  final items = all.where(_matches).toList();
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
                    itemBuilder: (_, i) => _BlacklistTile(
                      item: items[i],
                      onEdit: canManage ? () => _openForm(item: items[i]) : null,
                      onDelete: canManage ? () => _delete(items[i]) : null,
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
}

class _BlacklistTile extends StatelessWidget {
  const _BlacklistTile({required this.item, this.onEdit, this.onDelete});

  final BlacklistItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.errorContainer,
        child: Icon(Icons.block, color: theme.colorScheme.error),
      ),
      title: Text(item.name ?? item.phone ?? item.idNumber ?? '—', style: const TextStyle(fontWeight: .w600)),
      subtitle: Column(
        crossAxisAlignment: .start,
        spacing: 2,
        children: [
          Text([?item.phone, if (item.idNumber != null) 'ID: ${item.idNumber}'].join(' · ')),
          Text(item.reason, style: TextStyle(color: theme.colorScheme.error)),
          Text(
            [
              if (item.addedByName != null) 'By ${item.addedByName}',
              if (item.createdAt != null) fmtDateTime(item.createdAt),
            ].join(' · '),
            style: muted,
          ),
        ],
      ),
      isThreeLine: true,
      onTap: onEdit,
      trailing: onDelete == null
          ? null
          : IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: onDelete,
            ),
    );
  }
}

/// Add / edit form. Pops with a success message.
class _BlacklistForm extends ConsumerStatefulWidget {
  const _BlacklistForm({this.item, this.prefill});

  final BlacklistItem? item;
  final BlacklistInput? prefill;

  @override
  ConsumerState<_BlacklistForm> createState() => _BlacklistFormState();
}

class _BlacklistFormState extends ConsumerState<_BlacklistForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? widget.prefill?.name);
  late final _phone = TextEditingController(text: widget.item?.phone ?? widget.prefill?.phone);
  late final _idNumber = TextEditingController(text: widget.item?.idNumber ?? widget.prefill?.idNumber);
  late final _reason = TextEditingController(text: widget.item?.reason);

  @override
  void dispose() {
    for (final c in [_name, _phone, _idNumber, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final ok = await ref
        .read(blacklistMutationProvider.notifier)
        .save(
          id: widget.item?.id,
          input: BlacklistInput(
            name: opt(_name),
            phone: opt(_phone),
            idNumber: opt(_idNumber),
            reason: _reason.text.trim(),
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(widget.item == null ? 'Added to blacklist' : 'Updated successfully');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blacklistMutationProvider);
    final failure = state.error;
    String? err(String f) => failure is ServerFailure ? failure.fieldError(f) : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            spacing: 14,
            children: [
              Text(
                widget.item == null ? 'Add to Blacklist' : 'Edit Blacklist Entry',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: err('name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile',
                  hintText: '01XXXXXXXXX',
                  errorText: err('phone'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? null : Validators.bdPhone(v),
              ),
              TextFormField(
                controller: _idNumber,
                decoration: InputDecoration(
                  labelText: 'ID Number',
                  errorText: err('id_number'),
                  border: const OutlineInputBorder(),
                ),
              ),
              TextFormField(
                controller: _reason,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  errorText: err('reason'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => Validators.required(v, 'Reason'),
              ),
              Text(
                'Blacklisted mobile/ID numbers are blocked at check-in and pre-registration.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (failure is Failure && (failure is! ServerFailure || failure.errors == null))
                Text(failure.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: state.isLoading ? null : _save,
                child: state.isLoading
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
