import '../../../../core/network/api_client.dart';
import '../../../../shared/data/json_utils.dart';
import '../../../../shared/data/models/visit_model.dart';
import '../../domain/entities/dashboard_charts.dart';
import '../../domain/entities/dashboard_stats.dart';

class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._api);

  final ApiClient _api;

  Future<DashboardStats> stats() async {
    final d = await _api.get('dashboard/stats') as Map<String, dynamic>;
    int n(String key) => parseInt(d[key]) ?? 0;
    return DashboardStats(
      todayCheckins: n('today_checkins'),
      insideNow: n('inside_now'),
      todayCheckouts: n('today_checkouts'),
      pendingApprovals: n('pending_approvals'),
      expectedToday: n('expected_today'),
      todayPersons: n('today_persons'),
      monthVisits: n('month_visits'),
      totalVisitors: n('total_visitors'),
      recent: [for (final v in d['recent'] as List? ?? const []) VisitModel.fromJson(v as Map<String, dynamic>)],
    );
  }

  Future<DashboardCharts> charts(int days) async {
    final d = await _api.get('dashboard/charts', query: {'days': days}) as Map<String, dynamic>;
    List<LabelCount> counts(String key) => [
      for (final r in d[key] as List? ?? const []) LabelCount(r['label']?.toString() ?? '', parseInt(r['count']) ?? 0),
    ];
    return DashboardCharts(
      daily: [
        for (final r in d['daily'] as List? ?? const [])
          DailyCount(parseDateTime(r['date'])!, parseInt(r['count']) ?? 0),
      ],
      byType: counts('by_type'),
      byMethod: counts('by_method'),
      byDepartment: counts('by_department'),
    );
  }
}
