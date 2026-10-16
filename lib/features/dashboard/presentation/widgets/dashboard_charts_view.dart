import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../domain/entities/dashboard_charts.dart';
import '../providers/dashboard_providers.dart';
import 'chart_card.dart';

const _palette = [
  Color(0xFF006A4E), Color(0xFF1D5FC1), Color(0xFFF4A300), Color(0xFFF42A41), Color(0xFF0B7D93),
  Color(0xFF7B4BC4), Color(0xFF6C757D), Color(0xFF2E9E6A), Color(0xFFD66B00), Color(0xFF9AA5A1),
];

/// The four chart cards of the web dashboard, stacked for mobile.
class DashboardChartsView extends ConsumerWidget {
  const DashboardChartsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charts = ref.watch(dashboardChartsProvider);
    final days = ref.watch(chartDaysProvider);

    return AsyncValueView(
      value: charts,
      onRetry: () => ref.invalidate(dashboardChartsProvider),
      data: (c) => Column(
        crossAxisAlignment: .stretch,
        spacing: 12,
        children: [
          ChartCard(
            title: 'Daily Check-ins',
            action: SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [for (final d in ChartDays.options) ButtonSegment(value: d, label: Text('$d'))],
              selected: {days},
              onSelectionChanged: (s) => ref.read(chartDaysProvider.notifier).set(s.first),
            ),
            child: _DailyChart(c.daily),
          ),
          ChartCard(title: 'By Visit Type', subtitle: 'last 30 days', child: _TypeChart(c.byType)),
          ChartCard(
            title: 'By Department',
            subtitle: 'last 30 days',
            child: _DepartmentBars(c.byDepartment),
          ),
          ChartCard(
            title: 'By Check-in Method',
            subtitle: 'last 30 days',
            child: _MethodBreakdown(c.byMethod),
          ),
        ],
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart(this.daily);

  final List<DailyCount> daily;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final small = Theme.of(context).textTheme.labelSmall;
    final labelEvery = (daily.length / 7).ceil();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${fmtDate(daily[group.x].date)}\n${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => value % 1 == 0
                    ? SideTitleWidget(meta: meta, child: Text(value.toInt().toString(), style: small))
                    : const SizedBox.shrink(),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i % labelEvery != 0 || i >= daily.length) return const SizedBox.shrink();
                  return SideTitleWidget(meta: meta, child: Text(fmtDayMonth(daily[i].date), style: small));
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < daily.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: daily[i].count.toDouble(),
                  color: color,
                  width: daily.length > 15 ? 6 : 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _TypeChart extends StatelessWidget {
  const _TypeChart(this.rows);

  final List<LabelCount> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _NoData();
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 50,
              sectionsSpace: 2,
              sections: [
                for (var i = 0; i < rows.length; i++)
                  PieChartSectionData(
                    value: rows[i].count.toDouble(),
                    color: _palette[i % _palette.length],
                    radius: 34,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          alignment: .center,
          children: [
            for (var i = 0; i < rows.length; i++)
              _Legend(
                color: _palette[i % _palette.length],
                label: '${VisitType.fromValue(rows[i].label)?.label ?? rows[i].label} (${fmtNumber(rows[i].count)})',
              ),
          ],
        ),
      ],
    );
  }
}

/// Horizontal bars as a list: easier to read than a chart on a phone.
class _DepartmentBars extends StatelessWidget {
  const _DepartmentBars(this.rows);

  final List<LabelCount> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _NoData();
    final max = rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);
    return Column(
      spacing: 10,
      children: [
        for (final r in rows)
          _BarRow(
            label: r.label,
            trailing: fmtNumber(r.count),
            fraction: max == 0 ? 0 : r.count / max,
            color: const Color(0xFF1D5FC1),
          ),
      ],
    );
  }
}

class _MethodBreakdown extends StatelessWidget {
  const _MethodBreakdown(this.rows);

  final List<LabelCount> rows;

  @override
  Widget build(BuildContext context) {
    // Fixed order and colour per method, so a method keeps its colour even with no data.
    final counts = {for (final r in rows) r.label: r.count};
    final items = [for (final m in CheckinMethod.values) (m, counts[m.value] ?? 0)];
    final total = items.fold(0, (sum, x) => sum + x.$2);
    int pct(int n) => total == 0 ? 0 : (n * 100 / total).round();
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox.square(
          dimension: 120,
          child: Stack(
            alignment: .center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
                  sectionsSpace: total == 0 ? 0 : 2,
                  sections: total == 0
                      ? [PieChartSectionData(value: 1, color: theme.colorScheme.surfaceContainerHighest, radius: 14, showTitle: false)]
                      : [
                          for (final (m, n) in items)
                            PieChartSectionData(value: n.toDouble(), color: m.color, radius: 14, showTitle: false),
                        ],
                ),
              ),
              Column(
                mainAxisSize: .min,
                children: [
                  Text(fmtNumber(total), style: theme.textTheme.titleLarge?.copyWith(fontWeight: .w700)),
                  Text('Total', style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            spacing: 12,
            children: [
              for (final (m, n) in items)
                _BarRow(
                  icon: m.icon,
                  label: m.label,
                  trailing: '${fmtNumber(n)}  ${pct(n)}%',
                  fraction: total == 0 ? 0 : n / total,
                  color: m.color,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.trailing,
    required this.fraction,
    required this.color,
    this.icon,
  });

  final String label;
  final String trailing;
  final double fraction;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 4,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
            Expanded(child: Text(label, style: text.bodySmall, overflow: .ellipsis)),
            Text(trailing, style: text.labelMedium),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No data')),
      );
}
