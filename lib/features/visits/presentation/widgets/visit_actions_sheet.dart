import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/domain/visit_rules.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/status_chip.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/visit_entities.dart';
import '../pages/visit_form_page.dart';
import '../pages/visitor_pass_page.dart';
import '../providers/visit_action_providers.dart';

/// Visit details with the actions the user may take (web: visit detail modal).
Future<void> showVisitActionsSheet(BuildContext context, Visit visit) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => VisitActionsSheet(visit: visit),
);

class VisitActionsSheet extends ConsumerWidget {
  const VisitActionsSheet({super.key, required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final busy = ref.watch(visitActionProvider).isLoading;
    final theme = Theme.of(context);
    final v = visit;
    bool can(VisitAction a) => user != null && canDoVisit(a, v, user);

    final rows = [
      ('Mobile', v.visitorPhone),
      ('Email', v.visitorEmail),
      ('Visit No', v.visitNo),
      ('Visit Code', v.visitCode),
      ('Host', [v.hostName, ?v.hostDesignation].join(', ')),
      ('Department', [?v.departmentName, ?v.branchName].join(', ')),
      ('Visit Type', v.visitType?.label),
      ('Purpose', v.purpose),
      ('Persons', '${v.personsCount}'),
      ('Scheduled', v.scheduledAt == null ? null : fmtDateTime(v.scheduledAt)),
      ('Entry', v.checkInAt == null ? null : fmtDateTime(v.checkInAt)),
      ('Exit', v.checkOutAt == null ? null : fmtDateTime(v.checkOutAt)),
      ('Carrying Goods', v.carryingGoods),
      ('Vehicle No', v.vehicleNo),
      ('Card No', v.cardNo),
      ('Remarks', v.remarks),
    ].where((r) => r.$2 != null && r.$2!.isNotEmpty);

    Future<void> decide(VisitDecision d, String title, String okText, String inputLabel, Color color) async {
      final remarks = await askRemarks(context, title: title, okText: okText, inputLabel: inputLabel, color: color);
      if (remarks == null || !context.mounted) return;
      final done = await ref.read(visitActionProvider.notifier).decide(v.id, d, remarks: remarks);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (done != null) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (d) {
              VisitDecision.approve => 'Visit approved',
              VisitDecision.reject => 'Visit rejected',
              VisitDecision.cancel => 'Visit cancelled',
              VisitDecision.checkout => 'Checked out successfully',
            }),
          ),
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text('${ref.read(visitActionProvider).error}')));
      }
    }

    final actions = <Widget>[
      if (can(VisitAction.approve))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E9E6A)),
          onPressed: busy
              ? null
              : () => decide(
                  VisitDecision.approve,
                  'Approve this visit?',
                  'Approve',
                  'Remarks (optional)',
                  const Color(0xFF2E9E6A),
                ),
          icon: const Icon(Icons.check),
          label: const Text('Approve'),
        ),
      if (can(VisitAction.reject))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: busy
              ? null
              : () => decide(VisitDecision.reject, 'Reject this visit?', 'Reject', 'Reason', theme.colorScheme.error),
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
        ),
      if (can(VisitAction.checkin))
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            context.go('${AppRoutes.checkin}?visit=${v.id}');
          },
          icon: const Icon(Icons.login),
          label: const Text('Check-in'),
        ),
      if (can(VisitAction.checkout))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: VisitStatus.pending.color),
          onPressed: busy
              ? null
              : () => decide(
                  VisitDecision.checkout,
                  'Check out this visitor now?',
                  'Check-out',
                  'Remarks (optional)',
                  VisitStatus.pending.color,
                ),
          icon: const Icon(Icons.logout),
          label: const Text('Check-out'),
        ),
      if (can(VisitAction.pass))
        OutlinedButton.icon(
          onPressed: () => VisitorPassPage.open(context, v),
          icon: const Icon(Icons.qr_code),
          label: const Text('Visitor Pass'),
        ),
      if (can(VisitAction.edit))
        OutlinedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            final message = await VisitFormPage.open(context, visit: v);
            if (message != null) {
              navigator.pop();
              messenger.showSnackBar(SnackBar(content: Text(message)));
            }
          },
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
        ),
      if (can(VisitAction.cancel))
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => decide(VisitDecision.cancel, 'Cancel this visit?', 'Cancel Visit', 'Reason', Colors.black87),
          icon: const Icon(Icons.block),
          label: const Text('Cancel Visit'),
        ),
      if (can(VisitAction.delete))
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: busy
              ? null
              : () async {
                  final ok = await confirmDelete(context, 'Are you sure you want to delete this record?');
                  if (!ok || !context.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  if (await ref.read(visitActionProvider.notifier).delete(v.id)) {
                    navigator.pop();
                    messenger.showSnackBar(const SnackBar(content: Text('Deleted successfully')));
                  } else {
                    messenger.showSnackBar(SnackBar(content: Text('${ref.read(visitActionProvider).error}')));
                  }
                },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              VisitorAvatar(name: v.visitorName, photoUrl: v.visitorPhotoUrl, radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(v.visitorName, style: theme.textTheme.titleMedium),
                    if (v.visitorDesignation != null || v.visitorCompany != null)
                      Text([?v.visitorDesignation, ?v.visitorCompany].join(', '), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              StatusChip(v.status),
            ],
          ),
          const SizedBox(height: 16),
          if (actions.isNotEmpty) ...[
            if (busy) const LinearProgressIndicator(),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
            const SizedBox(height: 16),
          ],
          const Divider(),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: .start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(label, style: TextStyle(color: theme.colorScheme.outline)),
                  ),
                  Expanded(child: Text(value!)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
