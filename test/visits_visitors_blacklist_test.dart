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
import 'package:vms_app/features/blacklist/domain/blacklist_repository.dart';
import 'package:vms_app/features/blacklist/presentation/blacklist_providers.dart';
import 'package:vms_app/features/visitors/domain/visitor_repository.dart';
import 'package:vms_app/features/visitors/presentation/visitor_providers.dart';
import 'package:vms_app/features/visits/domain/entities/visit_entities.dart';
import 'package:vms_app/features/visits/domain/repositories/visit_repository.dart';
import 'package:vms_app/features/visits/presentation/providers/visit_providers.dart';
import 'package:vms_app/shared/domain/entities/paged.dart';
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

Visit _visit(int id, VisitStatus status) => Visit(
  id: id,
  visitNo: 'V-20261015-000$id',
  visitCode: 'CODE000$id',
  visitorName: 'Visitor $id',
  visitorCompany: 'Company $id',
  hostName: 'Farhana Islam',
  departmentName: 'Procurement',
  status: status,
  visitType: VisitType.vendor,
  personsCount: 2,
  checkInAt: status == VisitStatus.checkedIn ? DateTime(2026, 10, 15, 11, 57) : null,
  scheduledAt: DateTime(2026, 10, 15, 12, 30),
);

class _FakeVisits implements VisitRepository {
  VisitQuery? lastQuery;

  @override
  Future<Result<Paged<Visit>>> getVisits(VisitQuery query) async {
    lastQuery = query;
    final all = [_visit(1, VisitStatus.checkedIn), _visit(2, VisitStatus.pending)];
    final items = query.statuses.isEmpty ? all : all.where((v) => query.statuses.contains(v.status)).toList();
    return Success(Paged(items: items, total: items.length, page: 1, lastPage: 1));
  }

  @override
  Future<Result<Map<VisitStatus, int>>> statusCounts(VisitQuery query) async =>
      const Success({VisitStatus.checkedIn: 1, VisitStatus.pending: 1});

  @override
  Future<Result<Visit>> getVisit(int id) async => Success(_visit(id, VisitStatus.checkedOut));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitors implements VisitorRepository {
  @override
  Future<Result<Paged<VisitorProfile>>> getVisitors({String? q, int page = 1}) async => Success(
    Paged(
      items: [
        VisitorProfile(
          id: 28,
          name: 'Md. Arifur Rahman',
          phone: '01711223344',
          company: 'Grameenphone Ltd.',
          idType: IdType.nid,
          idNumber: '1990123456789',
          visitsCount: 3,
          lastVisit: DateTime(2026, 10, 14, 10),
        ),
      ],
      total: 1,
      page: 1,
      lastPage: 1,
    ),
  );

  @override
  Future<Result<VisitorDetail>> getVisitor(int id) async => Success(
    VisitorDetail(
      visitor: const VisitorProfile(id: 28, name: 'Md. Arifur Rahman', phone: '01711223344', blacklisted: true),
      visits: [
        Visit(
          id: 7,
          visitNo: 'V-7',
          visitCode: '',
          visitorName: 'Md. Arifur Rahman',
          hostName: 'Tanvir Ahmed',
          status: VisitStatus.checkedOut,
          visitType: VisitType.meeting,
          checkInAt: DateTime(2026, 10, 14, 10),
          checkOutAt: DateTime(2026, 10, 14, 11, 30),
        ),
      ],
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBlacklist implements BlacklistRepository {
  final saved = <BlacklistInput>[];

  @override
  Future<Result<List<BlacklistItem>>> getAll() async => Success([
    BlacklistItem(
      id: 3,
      name: 'Shahin Alam',
      phone: '01799887766',
      idNumber: '1234567890',
      reason: 'Misbehaved with security staff',
      addedByName: 'System Admin',
      createdAt: DateTime(2026, 10, 15),
    ),
  ]);

  @override
  Future<Result<BlacklistItem>> create(BlacklistInput input) async {
    saved.add(input);
    return Success(BlacklistItem(id: 9, reason: input.reason, phone: input.phone));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends AuthNotifier {
  @override
  Future<User?> build() async => _admin;
}

Future<({_FakeVisits visits, _FakeBlacklist blacklist})> _pump(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(360 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final visits = _FakeVisits();
  final blacklist = _FakeBlacklist();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_FakeAuth.new),
      visitRepositoryProvider.overrideWithValue(visits),
      visitorRepositoryProvider.overrideWithValue(_FakeVisitors()),
      blacklistRepositoryProvider.overrideWithValue(blacklist),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VmsApp()));
  await tester.pumpAndSettle();
  container.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
  return (visits: visits, blacklist: blacklist);
}

void main() {
  test('VisitQuery is value-equal so it can key the list provider', () {
    expect(
      const VisitQuery(statuses: [VisitStatus.pending], q: 'abc'),
      const VisitQuery(statuses: [VisitStatus.pending], q: 'abc'),
    );
    expect(const VisitQuery(q: 'a') == const VisitQuery(q: 'b'), isFalse);
  });

  test('blacklist entry needs a mobile or ID number', () async {
    final repo = _FakeBlacklist();
    final result = await SaveBlacklistEntry(repo)((id: null, input: const BlacklistInput(reason: 'x')));
    expect(((result as Error).failure as ServerFailure).fieldError('phone'), isNotNull);
    expect(repo.saved, isEmpty);
  });

  testWidgets('All Visits: list, status chips with counts, filter by status', (tester) async {
    final fakes = await _pump(tester, '/visits');

    expect(find.text('Visitor 1'), findsOneWidget);
    expect(find.text('Visitor 2'), findsOneWidget);
    expect(find.textContaining('Inside now', findRichText: true), findsOneWidget);
    expect(find.textContaining('All  2'), findsOneWidget);

    await tester.tap(find.textContaining('Pending  1'));
    await tester.pumpAndSettle();
    expect(fakes.visits.lastQuery!.statuses, [VisitStatus.pending]);
    expect(find.text('Visitor 1'), findsNothing);
    expect(find.text('Visitor 2'), findsOneWidget);

    // Tap opens the actions sheet; admin can delete.
    await tester.tap(find.text('Visitor 2'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('Visitor Profiles: list and profile with history and stats', (tester) async {
    await _pump(tester, '/visitors');

    expect(find.text('Md. Arifur Rahman'), findsOneWidget);
    expect(find.text('3 visits'), findsOneWidget);

    await tester.tap(find.text('Md. Arifur Rahman'));
    await tester.pumpAndSettle();
    expect(find.text('BLACKLISTED'), findsOneWidget);
    expect(find.text('1h 30m'), findsOneWidget); // average duration
    expect(find.textContaining('V-7'), findsOneWidget);
  });

  testWidgets('Blacklist: list, and add form pre-filled from a visitor profile', (tester) async {
    final fakes = await _pump(tester, '/blacklist?phone=01711223344&name=Arif');

    // Opened with the add form pre-filled.
    expect(find.text('Add to Blacklist'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Reason *'), 'Fake documents');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(fakes.blacklist.saved.single.phone, '01711223344');
    expect(fakes.blacklist.saved.single.name, 'Arif');
    expect(find.text('Shahin Alam'), findsOneWidget);
    expect(find.text('Added to blacklist'), findsOneWidget);
  });
}
