import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vms_app/app.dart';
import 'package:vms_app/core/storage/storage_providers.dart';
import 'package:vms_app/core/utils/result.dart';
import 'package:vms_app/features/auth/domain/entities/user.dart';
import 'package:vms_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vms_app/features/dashboard/domain/entities/dashboard_charts.dart';
import 'package:vms_app/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:vms_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vms_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vms_app/shared/domain/entities/visit.dart';

const _receptionist = User(
  id: 9,
  name: 'Abdul Karim (Front Desk)',
  username: 'reception',
  role: 'receptionist',
  roleName: 'Receptionist',
  permissions: ['visits.checkin', 'visits.preregister', 'visitors.view', 'reports.view'],
  isSuperAdmin: false,
  company: Company(id: 1, name: 'ABC Group Ltd.', code: 'ABC'),
);

class _FakeAuth extends AuthNotifier {
  @override
  Future<User?> build() async => _receptionist;
}

class _FakeRepo implements DashboardRepository {
  @override
  Future<Result<DashboardStats>> getStats() async => Success(DashboardStats(
        todayCheckins: 4,
        insideNow: 3,
        todayCheckouts: 1,
        pendingApprovals: 2,
        expectedToday: 2,
        todayPersons: 5,
        monthVisits: 70,
        totalVisitors: 25,
        recent: [
          Visit(
            id: 1,
            visitNo: 'V-1',
            visitCode: 'ABC',
            visitorName: 'Abul Kalam Azad',
            visitorCompany: 'PRAN-RFL Group',
            hostName: 'Farhana Islam',
            visitType: VisitType.vendor,
            status: VisitStatus.checkedIn,
            checkInAt: DateTime(2026, 10, 15, 11, 57),
          ),
          Visit(
            id: 2,
            visitNo: 'V-2',
            visitCode: 'DEF',
            visitorName: 'Rezaul Karim',
            hostName: 'Sharmin Akter',
            visitType: VisitType.meeting,
            status: VisitStatus.pending,
            scheduledAt: DateTime(2026, 10, 15, 16, 30),
          ),
        ],
      ));

  @override
  Future<Result<DashboardCharts>> getCharts({required int days}) async => Success(DashboardCharts(
        daily: [for (var i = 0; i < days; i++) DailyCount(DateTime(2026, 10, 1 + i), i % 9)],
        byType: const [LabelCount('meeting', 55), LabelCount('delivery', 22), LabelCount('vendor', 21)],
        byMethod: const [LabelCount('qr', 43), LabelCount('manual', 78), LabelCount('rfid', 29)],
        byDepartment: const [LabelCount('Accounts & Finance', 26), LabelCount('Information Technology (IT)', 21)],
      ));
}

void main() {
  testWidgets('dashboard renders at phone size without overflow', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_FakeAuth.new),
        dashboardRepositoryProvider.overrideWithValue(_FakeRepo()),
      ],
      child: const VmsApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Abdul Karim (Front Desk)'), findsOneWidget);
    expect(find.text('Inside Now'), findsOneWidget);
    expect(find.text('New Check-in'), findsOneWidget);

    // Switch the daily chart to 30 days.
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rezaul Karim'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Abul Kalam Azad'), findsOneWidget);

    // Drawer shows only permitted items: no Setup for a receptionist.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('Visitor Report'), findsOneWidget);
    expect(find.text('Branches'), findsNothing);

    // Advance past the 60 s auto-refresh timer so no timer is left pending.
    await tester.pump(const Duration(seconds: 61));
  });
}
