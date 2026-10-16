import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/dashboard_charts_view.dart';
import '../widgets/recent_activity.dart';
import '../widgets/stat_grid.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> _refresh(WidgetRef ref) {
    ref.invalidate(dashboardChartsProvider);
    // Errors are shown by the page itself.
    return ref.refresh(dashboardStatsProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final stats = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Welcome, ${user?.name ?? ''}', style: theme.textTheme.titleLarge),
            Text("Today's visitor activity at a glance",
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: [
                if (user?.can('visits.checkin') ?? false)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.checkin),
                      icon: const Icon(Icons.login),
                      label: const Text('New Check-in'),
                    ),
                  ),
                if (user?.can('visits.preregister') ?? false)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.preregister),
                      icon: const Icon(Icons.event_available),
                      label: const Text('Pre-register'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (stats.hasError && !stats.hasValue)
              AsyncValueView(
                value: stats,
                onRetry: () => ref.invalidate(dashboardStatsProvider),
                data: (_) => const SizedBox.shrink(),
              )
            else
              StatGrid(stats: stats.value),
            const SizedBox(height: 16),
            const DashboardChartsView(),
            const SizedBox(height: 16),
            if (stats.value case final s?) RecentActivity(visits: s.recent),
          ],
        ),
      ),
    );
  }
}
