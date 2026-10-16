class DashboardCharts {
  const DashboardCharts({
    required this.daily,
    required this.byType,
    required this.byMethod,
    required this.byDepartment,
  });

  final List<DailyCount> daily;

  /// Labels are API values (`meeting`, `qr`, ...) except for departments.
  final List<LabelCount> byType;
  final List<LabelCount> byMethod;
  final List<LabelCount> byDepartment;
}

class DailyCount {
  const DailyCount(this.date, this.count);

  final DateTime date;
  final int count;
}

class LabelCount {
  const LabelCount(this.label, this.count);

  final String label;
  final int count;
}
