import 'package:flutter/material.dart';

import '../../../../shared/presentation/formatters.dart';
import '../../domain/entities/dashboard_stats.dart';

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.stats});

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final cards = [
      ("Today's Check-ins", Icons.login, const Color(0xFF2E9E6A), s?.todayCheckins),
      ('Inside Now', Icons.meeting_room_outlined, const Color(0xFF1D5FC1), s?.insideNow),
      ("Today's Check-outs", Icons.logout, const Color(0xFF6C757D), s?.todayCheckouts),
      ('Pending Approvals', Icons.hourglass_top, const Color(0xFFF4A300), s?.pendingApprovals),
      ('Expected Today', Icons.event_available, const Color(0xFF0B7D93), s?.expectedToday),
      ("Today's Persons", Icons.groups_outlined, const Color(0xFF2E9E6A), s?.todayPersons),
      ("This Month's Visits", Icons.calendar_month, const Color(0xFF1D5FC1), s?.monthVisits),
      ('Total Visitor Profiles', Icons.contacts_outlined, const Color(0xFFF42A41), s?.totalVisitors),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 84,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, i) {
        final (label, icon, color, value) = cards[i];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        value == null ? '–' : fmtNumber(value),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: .w700),
                      ),
                      Text(label,
                          maxLines: 2,
                          overflow: .ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
