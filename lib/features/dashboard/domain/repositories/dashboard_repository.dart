import '../../../../core/utils/result.dart';
import '../entities/dashboard_charts.dart';
import '../entities/dashboard_stats.dart';

abstract interface class DashboardRepository {
  Future<Result<DashboardStats>> getStats();

  Future<Result<DashboardCharts>> getCharts({required int days});
}
