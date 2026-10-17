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
import 'package:vms_app/features/masters/data/master_repository_impl.dart';
import 'package:vms_app/features/masters/domain/master_entities.dart';
import 'package:vms_app/features/masters/domain/master_repository.dart';
import 'package:vms_app/features/masters/presentation/master_providers.dart';

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

class _Repo<T extends MasterItem> implements MasterRepository<T> {
  _Repo(this.items, {this.deleteError});

  final List<T> items;
  final Failure? deleteError;
  final saved = <T>[];

  @override
  Future<Result<List<T>>> getAll() async => Success(List.of(items));

  @override
  Future<Result<T>> save(T item) async {
    saved.add(item);
    return Success(item);
  }

  @override
  Future<Result<void>> delete(int id) async {
    if (deleteError != null) return Error(deleteError!);
    items.removeWhere((i) => i.id == id);
    return const Success(null);
  }
}

class _FakeAuth extends AuthNotifier {
  @override
  Future<User?> build() async => _admin;
}

class _OfflineDashboard implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(const Error<Never>(NetworkFailure()));
}

final _branches = _Repo<Branch>([
  const Branch(id: 1, name: 'Head Office', address: 'Gulshan, Dhaka', departmentsCount: 7, employeesCount: 10),
  const Branch(id: 4, name: 'Chattogram Office', active: false, departmentsCount: 1, employeesCount: 1),
], deleteError: const ServerFailure('This record is in use and cannot be deleted', statusCode: 409));
final _departments = _Repo<Department>([
  const Department(id: 3, name: 'Accounts & Finance', branchId: 1, branchName: 'Head Office', employeesCount: 1),
  const Department(id: 9, name: 'Chattogram Operations', branchId: 4, branchName: 'Chattogram Office'),
]);
final _employees = _Repo<Employee>([
  const Employee(
    id: 9,
    code: 'EMP-004',
    name: 'Farhana Islam',
    designation: 'Procurement Manager',
    departmentName: 'Procurement',
    branchName: 'Head Office',
    phone: '01712000004',
  ),
]);

Future<ProviderContainer> _pump(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(360 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_FakeAuth.new),
      dashboardRepositoryProvider.overrideWithValue(_OfflineDashboard()),
      branchRepositoryProvider.overrideWithValue(_branches),
      departmentRepositoryProvider.overrideWithValue(_departments),
      employeeRepositoryProvider.overrideWithValue(_employees),
    ],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VmsApp()));
  await tester.pumpAndSettle();
  container.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
  return container;
}

Future<void> _end(WidgetTester tester, ProviderContainer c) async {
  await tester.pump(const Duration(seconds: 5)); // let snackbars finish
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  test('employee JSON mapping matches EmployeeController', () {
    final e = employeeFromJson({
      'id': 9,
      'employee_code': 'EMP-004',
      'name': 'Farhana Islam',
      'department_id': 8,
      'branch_id': '1',
      'phone': '01712000004',
      'status': 0,
    });
    expect(e.active, isFalse);
    expect(e.branchId, 1);
    expect(employeeToJson(e), {
      'employee_code': 'EMP-004',
      'name': 'Farhana Islam',
      'designation': '',
      'department_id': 8,
      'branch_id': 1,
      'phone': '01712000004',
      'email': '',
      'status': 0,
    });
  });

  testWidgets('Branches: list, counts, status, refused delete shows the server message', (tester) async {
    final c = await _pump(tester, '/branches');
    expect(find.text('Branches (2)'), findsOneWidget);
    expect(find.text('Head Office'), findsOneWidget);
    expect(find.textContaining('7 departments · 10 employees'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);

    // Search.
    await tester.enterText(find.widgetWithText(TextField, 'Search'), 'chatto');
    await tester.pump();
    expect(find.text('Head Office'), findsNothing);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('This record is in use and cannot be deleted'), findsOneWidget);
    await _end(tester, c);
  });

  testWidgets('Departments: add with branch and required name', (tester) async {
    final c = await _pump(tester, '/departments');
    await tester.tap(find.text('Add New'));
    await tester.pumpAndSettle();

    // Name is required.
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'Security');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(_departments.saved.last.name, 'Security');
    expect(_departments.saved.last.branchId, 1); // default Head Office, like the web
    expect(find.text('Saved successfully'), findsOneWidget);
    await _end(tester, c);
  });

  testWidgets('Employees: picking a department picks its branch', (tester) async {
    final c = await _pump(tester, '/employees');
    expect(find.text('EMP-004'), findsOneWidget);
    expect(find.text('Farhana Islam'), findsOneWidget);

    await tester.tap(find.text('Add New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Employee Code *'), 'EMP-020');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'Rafiq Hasan');

    await tester.tap(find.text('Select').first); // Department dropdown
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chattogram Operations (Chattogram Office)').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile'), '0171');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Submit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid mobile number (01XXXXXXXXX)'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile'), '01712345678');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    final saved = _employees.saved.last;
    expect(saved.code, 'EMP-020');
    expect(saved.departmentId, 9);
    expect(saved.branchId, 4);
    await _end(tester, c);
  });
}
