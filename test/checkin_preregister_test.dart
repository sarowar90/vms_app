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
import 'package:vms_app/features/visits/domain/entities/visit_entities.dart';
import 'package:vms_app/features/visits/domain/repositories/visit_repository.dart';
import 'package:vms_app/features/visits/domain/usecases/visit_use_cases.dart';
import 'package:vms_app/features/visits/presentation/providers/visit_providers.dart';
import 'package:vms_app/shared/data/models/visit_model.dart';
import 'package:vms_app/shared/domain/entities/paged.dart';
import 'package:vms_app/shared/domain/entities/visit.dart';
import 'package:vms_app/shared/domain/visit_rules.dart';

const _receptionist = User(
  id: 9,
  name: 'Abdul Karim',
  username: 'reception',
  role: 'receptionist',
  roleName: 'Receptionist',
  permissions: ['visits.view_all', 'visits.checkin', 'visits.preregister', 'visits.edit', 'visits.cancel'],
  isSuperAdmin: false,
  company: Company(id: 1, name: 'ABC Group Ltd.', code: 'ABC'),
);

const _employee = User(
  id: 11,
  name: 'Nusrat Jahan',
  username: 'nusrat',
  role: 'employee',
  roleName: 'Employee',
  permissions: ['visits.preregister'],
  isSuperAdmin: false,
  employeeId: 2,
);

Visit _visit(int id, VisitStatus status, {int host = 2, int? createdBy}) => Visit(
  id: id,
  visitNo: 'V-$id',
  visitCode: 'CODE000$id',
  visitorName: 'Visitor $id',
  visitorPhone: '0171100000$id',
  hostName: 'Nusrat Jahan',
  hostEmployeeId: host,
  createdBy: createdBy,
  status: status,
  visitType: VisitType.meeting,
  scheduledAt: DateTime(2026, 10, 16, 15),
);

class _FakeVisitRepo implements VisitRepository {
  final requests = <Object>[];

  @override
  Future<Result<List<Host>>> getHosts() async =>
      const Success([Host(id: 2, name: 'Nusrat Jahan', departmentName: 'HR')]);

  @override
  Future<Result<List<VisitorProfile>>> searchVisitors(String query) async =>
      const Success([VisitorProfile(id: 28, name: 'Md. Arifur Rahman', phone: '01711223344')]);

  @override
  Future<Result<BlacklistEntry?>> checkBlacklist({String? phone, String? idNumber}) async =>
      Success(phone == '01799887766' ? const BlacklistEntry(name: 'Shahin', reason: 'Misbehaved') : null);

  @override
  Future<Result<Paged<Visit>>> getVisits(VisitQuery query) async {
    final items = [
      if (query.statuses.contains(VisitStatus.pending)) _visit(1, VisitStatus.pending),
      if (query.statuses.contains(VisitStatus.approved)) _visit(2, VisitStatus.approved),
    ];
    return Success(Paged(items: items, total: items.length, page: 1, lastPage: 1));
  }

  @override
  Future<Result<Visit>> getVisit(int id) async => Success(_visit(id, VisitStatus.approved));

  @override
  Future<Result<Visit>> lookup(String code) async => Success(_visit(2, VisitStatus.approved));

  @override
  Future<Result<Visit>> checkInWalkIn(WalkInCheckin request) async {
    requests.add(request);
    return Success(_visit(5, VisitStatus.checkedIn));
  }

  @override
  Future<Result<Visit>> checkInExisting(ExistingCheckin request) async {
    requests.add(request);
    return Success(_visit(request.visitId, VisitStatus.checkedIn));
  }

  @override
  Future<Result<Visit>> preregister(VisitForm form) async => Success(_visit(6, VisitStatus.approved));

  @override
  Future<Result<Visit>> update(int id, VisitForm form) async => Success(_visit(id, VisitStatus.approved));

  @override
  Future<Result<Visit>> decide(int id, VisitDecision decision, {String? remarks}) async =>
      Success(_visit(id, VisitStatus.approved));

  @override
  Future<Result<void>> delete(int id) async => const Success(null);

  @override
  Future<Result<List<Visit>>> activeVisits() async => const Success([]);

  @override
  Future<Result<Visit>> checkoutByCode(String code) async => Success(_visit(5, VisitStatus.checkedOut));

  @override
  Future<Result<Map<VisitStatus, int>>> statusCounts(VisitQuery query) async =>
      const Success({VisitStatus.pending: 1, VisitStatus.approved: 1});
}

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this.user);

  final User user;

  @override
  Future<User?> build() async => user;
}

Future<_FakeVisitRepo> _pumpApp(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(360 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeVisitRepo();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(() => _FakeAuth(_receptionist)),
      visitRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VmsApp()));
  await tester.pumpAndSettle();
  container.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('visit rules (same as web visits.js)', () {
    test('host employee can approve their own pending visit', () {
      expect(canDoVisit(VisitAction.approve, _visit(1, VisitStatus.pending), _employee), isTrue);
      expect(canDoVisit(VisitAction.approve, _visit(1, VisitStatus.pending, host: 99), _employee), isFalse);
    });

    test('pending visit cannot be checked in without visits.approve', () {
      expect(canDoVisit(VisitAction.checkin, _visit(1, VisitStatus.pending), _receptionist), isFalse);
      expect(canDoVisit(VisitAction.checkin, _visit(1, VisitStatus.approved), _receptionist), isTrue);
      expect(canDoVisit(VisitAction.checkin, _visit(1, VisitStatus.approved), _employee), isFalse);
    });

    test('creator can cancel an open visit; closed visits cannot be cancelled', () {
      expect(
        canDoVisit(VisitAction.cancel, _visit(1, VisitStatus.approved, host: 99, createdBy: 11), _employee),
        isTrue,
      );
      expect(canDoVisit(VisitAction.cancel, _visit(1, VisitStatus.rejected), _receptionist), isFalse);
    });
  });

  test('RFID check-in without a card number fails before calling the API', () async {
    final repo = _FakeVisitRepo();
    final result = await CheckInExisting(repo)(const ExistingCheckin(visitId: 2, method: CheckinMethod.rfid));
    expect(result, isA<Error<Visit>>());
    expect(((result as Error).failure as ServerFailure).fieldError('card_no'), isNotNull);
    expect(repo.requests, isEmpty);
  });

  test('VisitModel parses the live API visit JSON', () {
    final v = VisitModel.fromJson({
      'id': 347,
      'visit_no': 'V-20261015-0002',
      'visit_code': 'KES2MBPN',
      'visitor_name': 'Abul Kalam Azad',
      'visitor_phone': '01816445566',
      'host_employee_id': 9,
      'host_name': 'Farhana Islam',
      'visit_type': 'vendor',
      'persons_count': 2,
      'checkin_method': 'manual',
      'created_by': 9,
      'scheduled_at': '2026-10-15 12:30:00',
      'check_in_at': '2026-10-15 11:57:33',
      'status': 'checked_in',
    });
    expect(v.status, VisitStatus.checkedIn);
    expect(v.hostEmployeeId, 9);
    expect(v.checkinMethod, CheckinMethod.manual);
    expect(v.scheduledAt, DateTime(2026, 10, 15, 12, 30));
  });

  testWidgets('check-in page: walk-in form and pre-registered tab render and check in', (tester) async {
    final repo = await _pumpApp(tester, '/checkin');

    expect(find.text('Walk-in Visitor'), findsOneWidget);
    expect(find.text('Mobile *'), findsOneWidget);

    // Blacklist warning appears for a blacklisted number.
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile *'), '01799887766');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('BLACKLISTED'), findsWidgets);

    // Pre-registered tab: pick from Expected Today and check in.
    await tester.tap(find.text('Pre-registered / QR'));
    await tester.pumpAndSettle();
    expect(find.text('Expected Today'), findsOneWidget);
    await tester.tap(find.text('Visitor 2').first);
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('pre-checkin-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repo.requests.single, isA<ExistingCheckin>());
    expect(find.text('Checked in successfully'), findsOneWidget);
  });

  testWidgets('pre-registration page lists tabs and opens visit actions', (tester) async {
    await _pumpApp(tester, '/preregister');

    expect(find.descendant(of: find.byType(TabBar), matching: find.text('Pending')), findsOneWidget);
    expect(find.text('Visitor 1'), findsOneWidget);
    expect(find.text('Pre-register'), findsOneWidget);

    await tester.tap(find.text('Visitor 1'));
    await tester.pumpAndSettle();
    // Receptionist without visits.approve: no Approve button, but can edit/cancel.
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Cancel Visit'), findsOneWidget);
  });
}
