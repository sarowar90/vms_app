import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/status_chip.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../visits/presentation/providers/visit_providers.dart';
import '../../../visits/presentation/widgets/visit_actions_sheet.dart';
import '../../../visits/presentation/widgets/visit_tile.dart';
import '../../domain/visitor_repository.dart';
import '../visitor_providers.dart';
import 'visitor_edit_page.dart';

/// One visitor: identity, stats and visit history timeline (web: profile modal).
class VisitorProfilePage extends ConsumerWidget {
  const VisitorProfilePage({super.key, required this.visitorId});

  final int visitorId;

  static Future<void> open(BuildContext context, int id) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VisitorProfilePage(visitorId: id)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(visitorDetailProvider(visitorId));
    // Keep the auto-dispose delete notifier alive while this page is open.
    ref.watch(visitorMutationProvider);
    final user = ref.watch(authProvider).value;
    final d = detail.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Profile'),
        actions: [
          if (d != null)
            IconButton(
              tooltip: 'Edit Profile',
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final saved = await VisitorEditPage.open(context, d.visitor);
                if (saved) messenger.showSnackBar(const SnackBar(content: Text('Updated successfully')));
              },
            ),
          if (d != null && (user?.can('visitors.delete') ?? false))
            PopupMenuButton<String>(
              onSelected: (_) => _delete(context, ref),
              itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete visitor'))],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(visitorDetailProvider(visitorId).future).then((_) {}, onError: (_) {}),
        child: AsyncValueView(
          value: detail,
          onRetry: () => ref.invalidate(visitorDetailProvider(visitorId)),
          data: (d) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Hero(detail: d, canBlacklist: user?.can('blacklist.manage') ?? false),
              Padding(padding: const EdgeInsets.all(16), child: _Stats(d)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Visit History (${fmtNumber(d.visits.length)})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (d.visits.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No visits yet')),
                )
              else
                for (final v in d.visits) _HistoryItem(v),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDelete(
      context,
      'Delete this visitor profile? (Only possible if the visitor has no visits.)',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (await ref.read(visitorMutationProvider.notifier).delete(visitorId)) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Deleted successfully')));
    } else {
      messenger.showSnackBar(SnackBar(content: Text('${ref.read(visitorMutationProvider).error}')));
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail, required this.canBlacklist});

  final VisitorDetail detail;
  final bool canBlacklist;

  @override
  Widget build(BuildContext context) {
    final v = detail.visitor;
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = scheme.onPrimary;

    Widget chip(IconData icon, String? text) => text == null
        ? const SizedBox.shrink()
        : Chip(visualDensity: VisualDensity.compact, avatar: Icon(icon, size: 16), label: Text(text));

    return Container(
      color: scheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  VisitorAvatar(name: v.name, photoUrl: v.photoUrl, radius: 36),
                  if (v.blacklisted)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: scheme.error,
                        child: const Icon(Icons.block, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    Text(
                      v.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: onPrimary, fontWeight: .w700),
                    ),
                    Text(
                      [?v.designation, ?v.company].join(' · ').ifEmpty('Visitor profile'),
                      style: TextStyle(color: onPrimary.withValues(alpha: 0.85)),
                    ),
                    if (v.blacklisted)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(6)),
                        child: const Text(
                          'BLACKLISTED',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: .w700),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip(Icons.phone, v.phone),
              chip(Icons.email_outlined, v.email),
              chip(Icons.badge_outlined, v.idLabel),
              chip(Icons.place_outlined, v.address),
              chip(Icons.event, v.createdAt == null ? null : 'Registered on ${fmtDate(v.createdAt)}'),
            ],
          ),
          if (canBlacklist && !v.blacklisted) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: onPrimary,
                  side: BorderSide(color: onPrimary.withValues(alpha: 0.6)),
                ),
                onPressed: () => context.go(
                  Uri(
                    path: AppRoutes.blacklist,
                    queryParameters: {'phone': v.phone, 'name': v.name, 'id_number': ?v.idNumber},
                  ).toString(),
                ),
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Add to Blacklist'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.d);

  final VisitorDetail d;

  @override
  Widget build(BuildContext context) {
    final avg = d.averageMinutes;
    final items = [
      ('Total Visits', fmtNumber(d.visits.length), Icons.checklist, const Color(0xFF1D5FC1)),
      ('Completed', fmtNumber(d.completed.length), Icons.task_alt, const Color(0xFF2E9E6A)),
      ('Last Visit', d.lastVisit == null ? '–' : fmtDate(d.lastVisit), Icons.history, const Color(0xFF0B7D93)),
      ('Avg. Duration', avg == null ? '–' : fmtDuration(avg), Icons.hourglass_bottom, const Color(0xFFF4A300)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: [
        for (final (label, value, icon, color) in items)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: .center,
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(fontWeight: .w700, fontSize: 16),
                          overflow: .ellipsis,
                        ),
                        Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: .ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One past visit. Tap loads the full visit and opens its actions.
class _HistoryItem extends ConsumerWidget {
  const _HistoryItem(this.v);

  final Visit v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    final when = v.checkInAt ?? v.scheduledAt;
    final duration = v.checkInAt != null && v.checkOutAt != null
        ? fmtDuration(v.checkOutAt!.difference(v.checkInAt!).inMinutes)
        : null;
    final time = v.checkInAt != null
        ? '${fmtTime(v.checkInAt)} → ${v.checkOutAt != null ? fmtTime(v.checkOutAt) : '…'}'
        : 'Scheduled ${fmtTime(v.scheduledAt)}';

    return InkWell(
      onTap: () async {
        final result = await ref.read(getVisitProvider)(v.id);
        if (!context.mounted) return;
        switch (result) {
          case Success(:final value):
            showVisitActionsSheet(context, value);
          case Error(:final failure):
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: v.status.color.withValues(alpha: 0.15),
              child: Icon(visitTypeIcons[v.visitType] ?? Icons.circle_outlined, size: 18, color: v.status.color),
            ),
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
                          [v.visitNo, ?v.visitType?.label].join(' · '),
                          style: const TextStyle(fontWeight: .w600),
                        ),
                      ),
                      StatusChip(v.status),
                    ],
                  ),
                  if (v.purpose != null) Text(v.purpose!, style: theme.textTheme.bodySmall),
                  Text([if (when != null) fmtDate(when), time, ?duration].join(' · '), style: muted),
                  Text(
                    [
                      'Host: ${v.hostName}',
                      ?v.departmentName,
                      if (v.personsCount > 1) '${v.personsCount} persons',
                      ?v.checkinMethod?.label,
                    ].join(' · '),
                    style: muted,
                  ),
                  if (v.carryingGoods != null) Text('Goods: ${v.carryingGoods}', style: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
