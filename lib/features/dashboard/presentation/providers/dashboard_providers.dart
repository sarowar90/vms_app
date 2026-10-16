import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/usecase.dart';
import '../../data/datasources/dashboard_remote_data_source.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_charts.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_charts.dart';
import '../../domain/usecases/get_dashboard_stats.dart';
import '../../../visits/presentation/providers/visit_providers.dart';

// ---------- Dependency injection ----------

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(DashboardRemoteDataSource(ref.watch(apiClientProvider))),
);

final getDashboardStatsProvider = Provider((ref) => GetDashboardStats(ref.watch(dashboardRepositoryProvider)));
final getDashboardChartsProvider = Provider((ref) => GetDashboardCharts(ref.watch(dashboardRepositoryProvider)));

// ---------- State ----------

/// Stat cards + recent activity. Refreshes every 60 s like the web page.
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  ref.watch(visitsRevisionProvider);
  final timer = Timer(const Duration(seconds: 60), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return (await ref.watch(getDashboardStatsProvider)(const NoParams())).getOrThrow();
});

/// Range of the daily check-ins chart: 7, 15 or 30 days.
final chartDaysProvider = NotifierProvider<ChartDays, int>(ChartDays.new);

class ChartDays extends Notifier<int> {
  static const options = [7, 15, 30];

  @override
  int build() => 7;

  void set(int days) => state = days;
}

final dashboardChartsProvider = FutureProvider.autoDispose<DashboardCharts>((ref) async {
  final days = ref.watch(chartDaysProvider);
  return (await ref.watch(getDashboardChartsProvider)(days)).getOrThrow();
});
