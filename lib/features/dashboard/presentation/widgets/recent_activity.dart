import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/status_chip.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';

class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key, required this.visits});

  final List<Visit> visits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(child: Text('Recent Activity', style: theme.textTheme.titleSmall)),
                TextButton(onPressed: () => context.go(AppRoutes.visits), child: const Text('View all')),
              ],
            ),
          ),
          if (visits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No records found')),
            )
          else
            for (final v in visits) ...[const Divider(height: 1), _VisitTile(v)],
        ],
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile(this.v);

  final Visit v;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline);
    // Same rule as the web: show check-in time, or the scheduled time (muted) if not in yet.
    final timeLine = v.checkInAt != null
        ? 'In ${fmtDateTime(v.checkInAt)}${v.checkOutAt != null ? '  ·  Out ${fmtDateTime(v.checkOutAt)}' : ''}'
        : 'Scheduled ${fmtDateTime(v.scheduledAt)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          VisitorAvatar(name: v.visitorName, photoUrl: v.visitorPhotoUrl, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 2,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        v.visitorName,
                        style: const TextStyle(fontWeight: .w600),
                        overflow: .ellipsis,
                      ),
                    ),
                    StatusChip(v.status),
                  ],
                ),
                if (v.visitorCompany != null) Text(v.visitorCompany!, style: muted),
                Text(
                  ['Host: ${v.hostName}', if (v.visitType != null) v.visitType!.label].join('  ·  '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(timeLine, style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
