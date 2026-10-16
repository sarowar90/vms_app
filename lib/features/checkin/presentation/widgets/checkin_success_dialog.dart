import 'package:flutter/material.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../visits/presentation/pages/visitor_pass_page.dart';

/// Shown after a check-in, like the web success modal.
Future<void> showCheckinSuccess(BuildContext context, Visit v) {
  final checkedIn = v.status == VisitStatus.checkedIn;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        checkedIn ? Icons.check_circle : Icons.hourglass_top,
        color: checkedIn ? const Color(0xFF2E9E6A) : VisitStatus.pending.color,
        size: 56,
      ),
      title: Text(
        checkedIn ? 'Checked in successfully' : 'Visitor registered. Waiting for host approval.',
        textAlign: .center,
      ),
      content: Column(
        mainAxisSize: .min,
        children: [
          Text.rich(
            TextSpan(
              text: 'Visit No: ',
              children: [
                TextSpan(
                  text: v.visitNo,
                  style: const TextStyle(fontWeight: .w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('${v.visitorName} → ${v.hostName}', textAlign: .center),
        ],
      ),
      actionsAlignment: .center,
      actions: [
        if (checkedIn)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              VisitorPassPage.open(context, v);
            },
            icon: const Icon(Icons.qr_code),
            label: const Text('Visitor Pass'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('New Check-in')),
      ],
    ),
  );
}
