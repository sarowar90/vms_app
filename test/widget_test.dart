import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vms_app/app.dart';
import 'package:vms_app/core/storage/storage_providers.dart';
import 'package:vms_app/core/utils/result.dart';
import 'package:vms_app/features/dashboard/domain/entities/dashboard_charts.dart';
import 'package:vms_app/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:vms_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vms_app/features/dashboard/presentation/providers/dashboard_providers.dart';

void main() {
  testWidgets('shows the login page when there is no saved session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const VmsApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('VMS Login'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });

  test('dashboard stats provider exposes repository data', () async {
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository())],
    );
    addTearDown(container.dispose);

    final stats = await container.read(dashboardStatsProvider.future);
    expect(stats.insideNow, 3);
  });
}

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<Result<DashboardStats>> getStats() async => const Success(
    DashboardStats(
      todayCheckins: 4,
      insideNow: 3,
      todayCheckouts: 1,
      pendingApprovals: 2,
      expectedToday: 2,
      todayPersons: 5,
      monthVisits: 70,
      totalVisitors: 25,
      recent: [],
    ),
  );

  @override
  Future<Result<DashboardCharts>> getCharts({required int days}) async =>
      const Success(DashboardCharts(daily: [], byType: [], byMethod: [], byDepartment: []));
}
