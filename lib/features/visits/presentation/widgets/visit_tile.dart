import 'package:flutter/material.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/status_chip.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import 'visit_actions_sheet.dart';

const visitTypeIcons = {
  VisitType.meeting: Icons.groups_outlined,
  VisitType.interview: Icons.badge_outlined,
  VisitType.delivery: Icons.inventory_2_outlined,
  VisitType.service: Icons.build_outlined,
  VisitType.vendor: Icons.storefront_outlined,
  VisitType.other: Icons.more_horiz,
};

/// One visit in a list (web: a row of the All Visits table). Tap opens the actions sheet.
class VisitTile extends StatelessWidget {
  const VisitTile(this.v, {super.key});

  final Visit v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    final small = theme.textTheme.bodySmall;

    return InkWell(
      onTap: () => showVisitActionsSheet(context, v),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            VisitorAvatar(name: v.visitorName, photoUrl: v.visitorPhotoUrl, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: 3,
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
                  Text(v.visitorCompany ?? v.visitorPhone ?? '', style: muted, overflow: .ellipsis),
                  Row(
                    children: [
                      Icon(
                        visitTypeIcons[v.visitType] ?? Icons.circle_outlined,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          [
                            v.visitNo,
                            ?v.visitType?.label,
                            if (v.personsCount > 1) '${v.personsCount} persons',
                          ].join(' · '),
                          style: small,
                          overflow: .ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(['Host: ${v.hostName}', ?v.departmentName].join(' · '), style: small, overflow: .ellipsis),
                  _TimeLine(v),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same rules as the web "time" cell: entry → exit (or "Inside now") and duration,
/// otherwise the scheduled time.
class _TimeLine extends StatelessWidget {
  const _TimeLine(this.v);

  final Visit v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    if (v.checkInAt != null) {
      final inside = v.status == VisitStatus.checkedIn;
      return Text.rich(
        TextSpan(
          style: muted,
          children: [
            TextSpan(text: '${fmtDate(v.checkInAt)}  ${fmtTime(v.checkInAt)} → '),
            if (v.checkOutAt != null)
              TextSpan(text: fmtTime(v.checkOutAt))
            else
              TextSpan(
                text: 'Inside now',
                style: TextStyle(color: VisitStatus.checkedIn.color, fontWeight: .w600),
              ),
            if (v.durationMinutes != null) TextSpan(text: '  ·  ${fmtDuration(v.durationMinutes!)}'),
            if (v.checkinMethod != null && !inside) TextSpan(text: '  ·  ${v.checkinMethod!.label}'),
          ],
        ),
      );
    }
    if (v.scheduledAt != null) {
      return Text('${fmtDate(v.scheduledAt)}  ${fmtTime(v.scheduledAt)} · Scheduled', style: muted);
    }
    return Text('—', style: muted);
  }
}
