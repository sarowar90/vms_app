import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/validators.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../../domain/master_entities.dart';
import '../master_providers.dart';
import '../permission_labels.dart';
import '../widgets/master_list_page.dart';

/// Roles & Permissions (web: `roles.php`): one card per role with per-group coverage.
class RolesPage extends ConsumerWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final catalog = ref.watch(permissionCatalogProvider);
    // Keep the delete notifier alive while this page is open.
    ref.watch(roleMutationProvider);

    Future<void> openEditor(Role? role, {bool copy = false}) async {
      final message = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => RoleEditorPage(role: role, copy: copy),
        ),
      );
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    }

    Future<void> delete(Role r) async {
      final ok = await confirmDelete(context, 'Delete the role "${r.name}"?');
      if (!ok || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final failure = await ref.read(roleMutationProvider.notifier).delete(r.id!);
      messenger.showSnackBar(SnackBar(content: Text(failure?.message ?? 'Role deleted')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Roles & Permissions')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEditor(null),
        icon: const Icon(Icons.add_moderator_outlined),
        label: const Text('New Role'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(mastersRevisionProvider.notifier).bump(),
        child: AsyncValueView(
          value: roles,
          onRetry: () => ref.read(mastersRevisionProvider.notifier).bump(),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              Text(
                'Create roles and choose exactly what each role can do. Assign roles to users on the Users page.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final r in list)
                _RoleCard(
                  role: r,
                  catalog: catalog.value ?? const [],
                  onOpen: () => openEditor(r),
                  onCopy: () => openEditor(r, copy: true),
                  onDelete: () => delete(r),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.catalog,
    required this.onOpen,
    required this.onCopy,
    required this.onDelete,
  });

  final Role role;
  final List<(String, List<String>)> catalog;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = role;
    final total = catalog.fold<int>(0, (s, g) => s + g.$2.length);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            Row(
              children: [
                Icon(
                  r.isSystem ? Icons.verified_user : Icons.shield_outlined,
                  color: r.isSystem ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(r.name, style: theme.textTheme.titleMedium),
                      if (r.nameBn != null) Text(r.nameBn!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (r.isSystem)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: theme.colorScheme.error, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Built-in', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
              ],
            ),
            if (r.description != null) Text(r.description!, style: theme.textTheme.bodySmall),
            // Coverage per permission group, e.g. "Visits 4/7".
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (group, keys) in catalog) _GroupCoverage(group: group, keys: keys, granted: r.permissions),
              ],
            ),
            Text(
              '${r.usersCount} user(s) · '
              '${r.allAccess ? 'Full access' : '${r.permissions.length} / $total permissions'}',
              style: theme.textTheme.bodySmall,
            ),
            // Wraps on narrow phones instead of overflowing.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onOpen,
                  icon: Icon(r.isSystem ? Icons.visibility_outlined : Icons.edit_outlined, size: 18),
                  label: Text(r.isSystem ? 'View' : 'Edit'),
                ),
                if (!r.isSystem) ...[
                  TextButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Duplicate'),
                  ),
                  IconButton(
                    // A role with users cannot be deleted (server rule); say why.
                    tooltip: r.usersCount > 0 ? 'Assigned to users - move them to another role first' : 'Delete',
                    icon: Icon(
                      Icons.delete_outline,
                      color: r.usersCount > 0 ? theme.disabledColor : theme.colorScheme.error,
                    ),
                    onPressed: r.usersCount > 0 ? null : onDelete,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCoverage extends StatelessWidget {
  const _GroupCoverage({required this.group, required this.keys, required this.granted});

  final String group;
  final List<String> keys;
  final List<String> granted;

  @override
  Widget build(BuildContext context) {
    final n = keys.where(granted.contains).length;
    final color = n == 0
        ? Theme.of(context).colorScheme.outline
        : n == keys.length
        ? const Color(0xFF2E9E6A)
        : const Color(0xFFF4A300);
    final (label, icon) = permissionGroups[group] ?? (group, Icons.circle_outlined);
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: .min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$n/${keys.length}',
              style: TextStyle(color: color, fontSize: 12, fontWeight: .w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create / edit / duplicate a role, or view the built-in Admin role (read-only).
class RoleEditorPage extends ConsumerStatefulWidget {
  const RoleEditorPage({super.key, this.role, this.copy = false});

  final Role? role;

  /// Start a new role from [role]'s name and permissions.
  final bool copy;

  @override
  ConsumerState<RoleEditorPage> createState() => _RoleEditorPageState();
}

class _RoleEditorPageState extends ConsumerState<RoleEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.role == null ? '' : (widget.copy ? '${widget.role!.name} (copy)' : widget.role!.name),
  );
  late final _nameBn = TextEditingController(text: widget.role?.nameBn);
  late final _description = TextEditingController(text: widget.role?.description);
  late final Set<String> _granted = {...?widget.role?.permissions};

  bool get _locked => widget.role != null && widget.role!.isSystem && !widget.copy;
  bool get _editing => widget.role != null && !widget.copy;

  @override
  void dispose() {
    for (final c in [_name, _nameBn, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_granted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one permission')));
      return;
    }
    // Keep the catalog order, like the web form.
    final catalog = ref.read(permissionCatalogProvider).value ?? const [];
    final ordered = [for (final (_, keys) in catalog) ...keys.where(_granted.contains)];
    final saved = await ref
        .read(roleMutationProvider.notifier)
        .save(
          Role(
            id: _editing ? widget.role!.id : null,
            name: _name.text.trim(),
            nameBn: _nameBn.text.trim().isEmpty ? null : _nameBn.text.trim(),
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
            permissions: ordered.isEmpty ? _granted.toList() : ordered,
          ),
        );
    if (saved != null && mounted) Navigator.of(context).pop(_editing ? 'Role updated' : 'Role created');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(permissionCatalogProvider);
    final state = ref.watch(roleMutationProvider);
    final err = state.error;
    final total = catalog.value?.fold<int>(0, (s, g) => s + g.$2.length) ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_locked ? 'View Role' : (_editing ? 'Edit Role' : 'New Role')),
        actions: [
          if (!_locked)
            state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_locked)
              Card(
                color: const Color(0xFFF4A300).withValues(alpha: 0.15),
                child: const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text(
                    'This is the built-in Admin role. It always has every permission and cannot be changed or deleted.',
                  ),
                ),
              ),
            TextFormField(
              controller: _name,
              enabled: !_locked,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Role Name (English) *',
                errorText: masterFieldError(err, 'name'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => Validators.required(v, 'Role name'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameBn,
              enabled: !_locked,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Role Name (বাংলা)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              enabled: !_locked,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            // Wraps on narrow phones instead of overflowing.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Permissions', style: theme.textTheme.titleMedium),
                Chip(visualDensity: VisualDensity.compact, label: Text('${_granted.length} / $total')),
                if (!_locked) ...[
                  TextButton(
                    onPressed: () => setState(() {
                      for (final (_, keys) in catalog.value ?? const <(String, List<String>)>[]) {
                        _granted.addAll(keys);
                      }
                    }),
                    child: const Text('All'),
                  ),
                  TextButton(onPressed: () => setState(_granted.clear), child: const Text('None')),
                ],
              ],
            ),
            if (masterFieldError(err, 'permissions') case final e?)
              Text(e, style: TextStyle(color: theme.colorScheme.error)),
            AsyncValueView(
              value: catalog,
              onRetry: () => ref.invalidate(permissionCatalogProvider),
              data: (groups) => Column(
                children: [
                  for (final (group, keys) in groups)
                    _PermissionGroup(
                      group: group,
                      keys: keys,
                      granted: _granted,
                      enabled: !_locked,
                      onChanged: () => setState(() {}),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One group card of the permission matrix, with an all/none switch.
class _PermissionGroup extends StatelessWidget {
  const _PermissionGroup({
    required this.group,
    required this.keys,
    required this.granted,
    required this.enabled,
    required this.onChanged,
  });

  final String group;
  final List<String> keys;
  final Set<String> granted;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final n = keys.where(granted.contains).length;
    final (label, icon) = permissionGroups[group] ?? (group, Icons.circle_outlined);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: theme.colorScheme.primary),
            title: Text(label, style: const TextStyle(fontWeight: .w600)),
            trailing: Checkbox(
              tristate: true,
              value: n == 0 ? false : (n == keys.length ? true : null),
              onChanged: !enabled
                  ? null
                  : (_) {
                      if (n == keys.length) {
                        granted.removeAll(keys);
                      } else {
                        granted.addAll(keys);
                      }
                      onChanged();
                    },
            ),
          ),
          const Divider(height: 1),
          for (final key in keys)
            CheckboxListTile(
              dense: true,
              value: granted.contains(key),
              onChanged: !enabled
                  ? null
                  : (on) {
                      on == true ? granted.add(key) : granted.remove(key);
                      onChanged();
                    },
              title: Text(permissionLabels[key]?.$1 ?? key),
              subtitle: permissionLabels[key]?.$2 == null ? null : Text(permissionLabels[key]!.$2!),
            ),
        ],
      ),
    );
  }
}
