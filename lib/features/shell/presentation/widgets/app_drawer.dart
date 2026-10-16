import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Side menu filtered by the user's permissions, like the web sidebar.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const Drawer();

    final current = GoRouterState.of(context).matchedLocation;
    final items = (user.isSuperAdmin ? superAdminNav : companyNav)
        .where((i) => user.canAny(i.permissions))
        .toList();
    final theme = Theme.of(context);

    final tiles = <Widget>[];
    String? group;
    for (final item in items) {
      if (item.group != group && item.group != null) {
        tiles.add(Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 6),
          child: Text(item.group!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ));
      }
      group = item.group;
      tiles.add(NavigationDrawerDestinationTile(
        item: item,
        selected: item.route == current,
        onTap: () {
          Navigator.of(context).pop();
          if (item.route != current) context.go(item.route);
        },
      ));
    }

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user.name),
            accountEmail: Text(
              [user.roleName, user.company?.name ?? 'Platform'].join(' · '),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary,
              child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: TextStyle(fontSize: 24, color: theme.colorScheme.primary)),
            ),
          ),
          Expanded(child: ListView(padding: EdgeInsets.zero, children: tiles)),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text('Logout', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).logout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class NavigationDrawerDestinationTile extends StatelessWidget {
  const NavigationDrawerDestinationTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        leading: Icon(item.icon),
        title: Text(item.label),
        onTap: onTap,
      ),
    );
  }
}
