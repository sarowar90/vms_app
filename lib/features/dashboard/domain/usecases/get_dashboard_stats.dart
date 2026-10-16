import '../../../../core/utils/result.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/dashboard_stats.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardStats implements UseCase<DashboardStats, NoParams> {
  const GetDashboardStats(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Result<DashboardStats>> call(NoParams params) => _repository.getStats();
}
