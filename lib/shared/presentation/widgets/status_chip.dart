import 'package:flutter/material.dart';

import '../../domain/entities/visit.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.label,
        style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
