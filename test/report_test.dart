import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vms_app/app.dart';
import 'package:vms_app/core/error/failures.dart';
import 'package:vms_app/core/router/app_router.dart';
import 'package:vms_app/core/storage/storage_providers.dart';
import 'package:vms_app/core/utils/result.dart';
import 'package:vms_app/features/auth/domain/entities/user.dart';
import 'package:vms_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vms_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vms_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vms_app/features/reports/data/report_repository_impl.dart';
import 'package:vms_app/features/reports/domain/report_entities.dart';
import 'package:vms_app/features/reports/domain/report_repository.dart';
import 'package:vms_app/features/reports/domain/report_use_cases.dart';
import 'package:vms_app/features/reports/presentation/report_providers.dart';
import 'package:vms_app/shared/domain/entities/visit.dart';

const _admin = User(
  id: 1,
  name: 'System Admin',
  username: 'admin',
  role: 'admin',
  roleName: 'Admin',
  permissions: [],
  isSuperAdmin: false,
  company: Company(id: 1, name: 'ABC Group Ltd.', code: 'ABC'),
);

const _columns = [
  ReportColumn(key: 'visit_no', label: 'Visit No', isDefault: true, sortable: true),
  ReportColumn(key: 'visitor_name', label: 'Visitor Name', isDefault: true, sortable: true),
  ReportColumn(key: 'check_in_at', label: 'Entry Date & Time', isDefault: true, sortable: true),
  ReportColumn(key: 'visit_type', label: 'Visit Type', isDefault: true, sortable: true),
  ReportColumn(key: 'status', label: 'Visitor Status', isDefault: true, sortable: true),
  ReportColumn(key: 'card_no', label: 'Card No (RFID)', isDefault: false, sortable: false),
];

class _FakeReports implements ReportRepository {
  final queries = <(ReportFilter, ReportLayout)>[];
  ReportLayout? stored;
  List<ReportPreset> storedPresets = const [];

  @override
  Future<Result<List<ReportColumn>>> columns() async => const Success(_columns);

  @override
  Future<Result<ReportPage>> visits(ReportFilter filter, ReportLayout layout, {int page = 1, int perPage = 50}) async {
    queries.add((filter, layout));
    return const Success(
      ReportPage(
        rows: [
          ReportRow(
            id: 349,
            values: {
              'visit_no': 'V-20261015-0004',
              'visitor_name': 'Habibur Rahman',
              'check_in_at': '2026-10-15 11:57:33',
              'visit_type': 'service',
              'status': 'checked_in',
            },
          ),
        ],
        totals: ReportTotals(visits: 83, persons: 118, inside: 3, withGoods: 51),
        page: 1,
        lastPage: 1,
      ),
    );
  }

  @override
  Future<Result<List<SummaryRow>>> summary(ReportFilter filter, ReportGroup group) async => const Success([
    SummaryRow(label: 'meeting', visits: 30, persons: 40, completed: 28, avgMinutes: 85),
    SummaryRow(label: 'delivery', visits: 10, persons: 10, completed: 10),
  ]);

  @override
  Future<Result<ExportFile>> export(ReportFilter filter, ReportLayout layout, ExportFormat format) async =>
      const Error(ServerFailure('not in tests'));

  @override
  Future<Result<List<NamedOption>>> departments() async => const Success([NamedOption(3, 'Accounts & Finance')]);

  @override
  Future<Result<List<NamedOption>>> branches() async => const Success([NamedOption(1, 'Head Office')]);

  @override
  ReportLayout? savedLayout() => stored;

  @override
  Future<void> saveLayout(ReportLayout layout) async => stored = layout;

  @override
  List<ReportPreset> presets() => storedPresets;

  @override
  Future<void> savePresets(List<ReportPreset> presets) async => storedPresets = presets;
}

class _FakeAuth extends AuthNotifier {
  @override
  Future<User?> build() async => _admin;
}

class _OfflineDashboard implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(const Error<Never>(NetworkFailure()));
}

void main() {
  group('ReportRange', () {
    test('this week starts on Saturday (Bangladesh)', () {
      // 2026-10-16 is a Friday -> week started Saturday 2026-10-10.
      final (from, to) = ReportRange.week.dates(DateTime(2026, 10, 16, 9, 58));
      expect(from, DateTime(2026, 10, 10));
      expect(to, DateTime(2026, 10, 16));
      // On a Saturday the week starts that day.
      expect(ReportRange.week.dates(DateTime(2026, 10, 17)).$1, DateTime(2026, 10, 17));
    });

    test('this month / year', () {
      expect(ReportRange.month.dates(DateTime(2026, 10, 16)).$1, DateTime(2026, 10));
      expect(ReportRange.year.dates(DateTime(2026, 10, 16)).$1, DateTime(2026));
    });
  });

  test('ReportFilter: value equality and saved-report round trip without dates', () {
    final f = ReportFilter(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 16),
      statuses: const {VisitStatus.checkedIn, VisitStatus.checkedOut},
      types: const {VisitType.delivery},
      hasGoods: true,
      text: const {'card_no': 'RF-1007'},
    );
    expect(f, ReportFilter.fromJson(f.toJson()));
    final saved = ReportFilter.fromJson(f.toJson(withDates: false));
    expect(saved.from, isNull);
    expect(saved.withDates(f.from, f.to), f);
  });

  test('filter query matches VisitController::filters()', () {
    final q = ReportRemoteDataSource.filterQuery(
      ReportFilter(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 16),
        types: const {VisitType.delivery},
        hasGoods: true,
        departmentId: 3,
        text: const {'vehicle_no': 'Dhaka', 'remarks': ' '},
      ),
    );
    expect(q, {
      'from': '2026-10-01',
      'to': '2026-10-16',
      'visit_type': 'delivery',
      'department_id': 3,
      'has_goods': 1,
      'f_vehicle_no': 'Dhaka',
    });
  });

  testWidgets('report page: totals, rows, sort, range, summary, column layout', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeReports();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_FakeAuth.new),
        reportRepositoryProvider.overrideWithValue(repo),
        dashboardRepositoryProvider.overrideWithValue(_OfflineDashboard()),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VmsApp()));
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/reports');
    await tester.pumpAndSettle();

    // Totals + one row with the default columns.
    expect(find.text('83'), findsOneWidget);
    expect(find.text('118'), findsOneWidget);
    expect(find.text('Habibur Rahman'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
    expect(repo.queries.last.$2.columns, ['visit_no', 'visitor_name', 'check_in_at', 'visit_type', 'status']);
    // Starts with "This Month".
    expect(repo.queries.last.$1.from!.day, 1);

    // Quick range: Today.
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.$1.from, repo.queries.last.$1.to);

    // Toggle sort direction -> stored on the device.
    await tester.tap(find.byTooltip('Descending'));
    await tester.pumpAndSettle();
    expect(repo.stored!.descending, isFalse);

    // Summary tab.
    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();
    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text('30  ·  75%'), findsOneWidget);
    expect(find.text('40 persons · 28 completed · avg 1h 25m'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
