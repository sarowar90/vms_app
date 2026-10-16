import '../../../../core/utils/guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/dashboard_charts.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_data_source.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._remote);

  final DashboardRemoteDataSource _remote;

  @override
  Future<Result<DashboardStats>> getStats() => guard(_remote.stats);

  @override
  Future<Result<DashboardCharts>> getCharts({required int days}) => guard(() => _remote.charts(days));
}
