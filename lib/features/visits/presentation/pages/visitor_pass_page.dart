import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/status_chip.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// On-screen visitor pass with the visit-code QR (web: `badge.php`).
/// The visitor can show it at the gate, or the guard can scan it at check-out.
class VisitorPassPage extends ConsumerWidget {
  const VisitorPassPage({super.key, required this.visit});

  final Visit visit;

  static Future<void> open(BuildContext context, Visit visit) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VisitorPassPage(visit: visit)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(authProvider).value?.company?.name;
    final theme = Theme.of(context);
    final v = visit;

    final rows = [
      ('Visit No', v.visitNo),
      ('Host', [v.hostName, ?v.departmentName].join(' — ')),
      if (v.visitType != null) ('Visit Type', v.visitType!.label),
      if (v.checkInAt != null) ('Entry', fmtDateTime(v.checkInAt)) else ('Scheduled', fmtDateTime(v.scheduledAt)),
      if (v.personsCount > 1) ('Persons', '${v.personsCount}'),
      if (v.cardNo != null) ('Card No', v.cardNo!),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Pass')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      (company ?? 'VISITOR').toUpperCase(),
                      textAlign: .center,
                      style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: .w700, letterSpacing: 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      spacing: 12,
                      children: [
                        VisitorAvatar(name: v.visitorName, photoUrl: v.visitorPhotoUrl, radius: 40),
                        Text(v.visitorName, style: theme.textTheme.titleLarge, textAlign: .center),
                        if (v.visitorCompany != null) Text(v.visitorCompany!, style: theme.textTheme.bodyMedium),
                        StatusChip(v.status),
                        QrImageView(data: v.visitCode, size: 180, backgroundColor: Colors.white),
                        SelectableText(
                          v.visitCode,
                          style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 4, fontWeight: .w700),
                        ),
                        const Divider(),
                        for (final (label, value) in rows)
                          Row(
                            crossAxisAlignment: .start,
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(label, style: TextStyle(color: theme.colorScheme.outline)),
                              ),
                              Expanded(child: Text(value)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
