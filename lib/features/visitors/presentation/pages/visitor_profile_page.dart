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
import '../../../visits/domain/entities/visit_entities.dart';
import '../../../visits/presentation/providers/visit_providers.dart';
import '../../../visits/presentation/widgets/visit_actions_sheet.dart';
import '../../../visits/presentation/widgets/visit_tile.dart';
import '../../domain/visitor_repository.dart';
import '../visitor_providers.dart';
import 'visitor_edit_page.dart';

const _green = Color(0xFF006A4E);
const _greenDeep = Color(0xFF0F2A22);

/// One visitor: identity, stats, contact details and visit history (web: profile modal).
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
        // Same green as the header below, so they read as one block.
        backgroundColor: _green,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Visitor Profile'),
        actions: [
          if (d != null)
            IconButton(
              tooltip: 'Edit Profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, d),
            ),
          if (d != null && (user?.can('visitors.delete') ?? false))
            PopupMenuButton<String>(
              onSelected: (_) => _delete(context, ref),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete visitor')),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(visitorDetailProvider(visitorId).future).then((_) {}, onError: (_) {}),
        child: AsyncValueView(
          value: detail,
          onRetry: () => ref.invalidate(visitorDetailProvider(visitorId)),
          data: (d) => ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(visitor: d.visitor, canBlacklist: user?.can('blacklist.manage') ?? false),
              // Pulled up so the stats card overlaps the header.
              Transform.translate(
                offset: const Offset(0, -44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    spacing: 16,
                    children: [_StatsCard(d), _ContactCard(d.visitor), _History(d.visits)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, VisitorDetail d) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await VisitorEditPage.open(context, d.visitor);
    if (saved) messenger.showSnackBar(const SnackBar(content: Text('Updated successfully')));
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

/// Green gradient header with photo, name, role and the blacklist state.
class _Header extends StatelessWidget {
  const _Header({required this.visitor, required this.canBlacklist});

  final VisitorProfile visitor;
  final bool canBlacklist;

  @override
  Widget build(BuildContext context) {
    final v = visitor;
    final error = Theme.of(context).colorScheme.error;
    final subtitle = [?v.designation, ?v.company].join(' · ');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_green, _greenDeep]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      // Extra bottom space for the overlapping stats card.
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 64),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: v.blacklisted ? error : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16)],
                ),
                child: VisitorAvatar(name: v.name, photoUrl: v.photoUrl, radius: 46),
              ),
              if (v.blacklisted)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: error,
                      child: const Icon(Icons.block, size: 15, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            v.name,
            textAlign: .center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: .w700),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: .center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
          const SizedBox(height: 14),
          if (v.blacklisted)
            _Pill(icon: Icons.block, label: 'BLACKLISTED', background: error, foreground: Colors.white)
          else if (canBlacklist)
            Material(
              color: Colors.white.withValues(alpha: 0.12),
              shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.35))),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => context.go(
                  Uri(
                    path: AppRoutes.blacklist,
                    queryParameters: {'phone': v.phone, 'name': v.name, 'id_number': ?v.idNumber},
                  ).toString(),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: .min,
                    spacing: 6,
                    children: [
                      Icon(Icons.block, size: 16, color: Colors.white),
                      Text(
                        'Add to Blacklist',
                        style: TextStyle(color: Colors.white, fontWeight: .w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.background, required this.foreground});

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: .min,
      spacing: 6,
      children: [
        Icon(icon, size: 16, color: foreground),
        Text(
          label,
          style: TextStyle(color: foreground, fontWeight: .w700, letterSpacing: 0.5),
        ),
      ],
    ),
  );
}

/// Four stats in one card: total, completed, last visit, average duration.
class _StatsCard extends StatelessWidget {
  const _StatsCard(this.d);

  final VisitorDetail d;

  @override
  Widget build(BuildContext context) {
    final avg = d.averageMinutes;
    final items = [
      ('Total Visits', fmtNumber(d.visits.length), Icons.checklist, const Color(0xFF1D5FC1)),
      ('Completed', fmtNumber(d.completed.length), Icons.task_alt, const Color(0xFF2E9E6A)),
      ('Last Visit', d.lastVisit == null ? '–' : fmtDayMonth(d.lastVisit!), Icons.history, const Color(0xFF0B7D93)),
      ('Avg. Stay', avg == null ? '–' : fmtDuration(avg), Icons.hourglass_bottom, const Color(0xFFF4A300)),
    ];
    final divider = Theme.of(context).colorScheme.outlineVariant;

    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (i, (label, value, icon, color)) in items.indexed) ...[
              if (i > 0) VerticalDivider(width: 1, color: divider),
              Expanded(
                child: Column(
                  spacing: 6,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: const TextStyle(fontWeight: .w700, fontSize: 16)),
                    ),
                    Text(
                      label,
                      textAlign: .center,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Contact & identity details as labelled rows.
class _ContactCard extends StatelessWidget {
  const _ContactCard(this.v);

  final VisitorProfile v;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (Icons.phone_outlined, 'Mobile', v.phone),
      (Icons.email_outlined, 'Email', v.email),
      (Icons.badge_outlined, (v.idType ?? IdType.other).label, v.idNumber),
      (Icons.wc_outlined, 'Gender', v.gender?.label),
      (Icons.place_outlined, 'Address', v.address),
      (Icons.event_outlined, 'Registered on', v.createdAt == null ? null : fmtDate(v.createdAt)),
    ].where((r) => r.$3 != null && r.$3!.isNotEmpty).toList();
    final theme = Theme.of(context);

    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          const _SectionTitle('Contact & Identity'),
          for (final (i, (icon, label, value)) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 52, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _green.withValues(alpha: 0.08),
                    child: Icon(icon, size: 18, color: _green),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                        Text(value!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: .w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Visit history as a timeline (newest first).
class _History extends StatelessWidget {
  const _History(this.visits);

  final List<Visit> visits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            const _SectionTitle('Visit History'),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(
                fmtNumber(visits.length),
                style: const TextStyle(color: _green, fontWeight: .w700, fontSize: 12),
              ),
            ),
          ],
        ),
        if (visits.isEmpty)
          _Card(
            padding: const EdgeInsets.all(28),
            child: Column(
              spacing: 6,
              children: [
                Icon(Icons.event_busy_outlined, size: 36, color: theme.colorScheme.outline),
                Text('No visits yet', style: TextStyle(color: theme.colorScheme.outline)),
              ],
            ),
          )
        else
          for (final (i, v) in visits.indexed) _TimelineItem(v, isLast: i == visits.length - 1),
      ],
    );
  }
}

class _TimelineItem extends ConsumerWidget {
  const _TimelineItem(this.v, {required this.isLast});

  final Visit v;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = v.checkInAt ?? v.scheduledAt;
    final duration = v.checkInAt != null && v.checkOutAt != null
        ? fmtDuration(v.checkOutAt!.difference(v.checkInAt!).inMinutes)
        : null;
    final time = v.checkInAt != null
        ? '${fmtTime(v.checkInAt)} → ${v.checkOutAt != null ? fmtTime(v.checkOutAt) : 'inside'}'
        : 'Scheduled ${fmtTime(v.scheduledAt)}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          // Rail: status dot + line to the next visit.
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: v.status.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: v.status.color.withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: theme.colorScheme.outlineVariant)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Card(
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 6,
                  children: [
                    Row(
                      children: [
                        Icon(visitTypeIcons[v.visitType] ?? Icons.circle_outlined, size: 18, color: _green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            v.visitType?.label ?? 'Visit',
                            style: const TextStyle(fontWeight: .w700),
                            overflow: .ellipsis,
                          ),
                        ),
                        StatusChip(v.status),
                      ],
                    ),
                    Text(v.visitNo, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                    if (v.purpose != null) Text(v.purpose!, style: theme.textTheme.bodyMedium),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (when != null) _Meta(Icons.calendar_today_outlined, fmtDate(when)),
                        _Meta(Icons.schedule, time),
                        if (duration != null) _Meta(Icons.hourglass_bottom, duration),
                        _Meta(Icons.person_outline, [v.hostName, ?v.departmentName].join(' · ')),
                        if (v.personsCount > 1) _Meta(Icons.groups_outlined, '${v.personsCount} persons'),
                        if (v.checkinMethod != null) _Meta(v.checkinMethod!.icon, v.checkinMethod!.label),
                        if (v.carryingGoods != null) _Meta(Icons.inventory_2_outlined, v.carryingGoods!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: .min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: .w700)),
  );
}

/// White rounded card with a soft shadow, optionally tappable.
class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding, this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.12),
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}
