import '../../../../core/utils/result.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/dashboard_charts.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardCharts implements UseCase<DashboardCharts, int> {
  const GetDashboardCharts(this._repository);

  final DashboardRepository _repository;

  /// [days] is the range of the daily chart: 7, 15 or 30.
  @override
  Future<Result<DashboardCharts>> call(int days) => _repository.getCharts(days: days);
}
