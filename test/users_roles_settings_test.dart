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
import 'package:vms_app/features/settings/domain/settings_repository.dart';
import 'package:vms_app/features/settings/presentation/settings_page.dart';

const _admin = User(
  id: 1,
  name: 'System Admin',
  username: 'admin',
  role: 'admin',
  roleName: 'Admin',
  permissions: [],
  isSuperAdmin: false,
  company: Company(id: 1, name: 'ABC Group Ltd.', code: 'AGL'),
);

const _catalog = [
  ('visits', ['visits.view_all', 'visits.checkin', 'visits.preregister']),
  ('reports', ['reports.view', 'reports.export']),
];

class _Repo<T extends MasterItem> implements MasterRepository<T> {
  _Repo(this.items);

  final List<T> items;
  final saved = <T>[];

  @override
  Future<Result<List<T>>> getAll() async => Success(List.of(items));

  @override
  Future<Result<T>> save(T item) async {
    saved.add(item);
    return Success(item);
  }

  @override
  Future<Result<void>> delete(int id) async => const Success(null);
}

class _Settings implements SettingsRepository {
  CompanySettings? saved;

  @override
  Future<Result<CompanySettings>> get() async => const Success(
    CompanySettings(
      companyName: 'ABC Group Ltd.',
      companyNameBn: 'এবিসি গ্রুপ লিমিটেড',
      badgeFooter: 'Please return this pass at the reception before leaving.',
      companyCode: 'AGL',
    ),
  );

  @override
  Future<Result<CompanySettings>> save(CompanySettings settings) async {
    saved = settings;
    return Success(settings);
  }

  @override
  Future<Result<String?>> uploadLogo(String dataUri) async => const Success(null);
}

class _FakeAuth extends AuthNotifier {
  @override
  Future<User?> build() async => _admin;
}

class _OfflineDashboard implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(const Error<Never>(NetworkFailure()));
}

final _roles = _Repo<Role>([
  const Role(
    id: 1,
    name: 'Admin',
    slug: 'admin',
    isSystem: true,
    allAccess: true,
    usersCount: 1,
    permissions: ['visits.view_all', 'visits.checkin', 'visits.preregister', 'reports.view', 'reports.export'],
  ),
  const Role(
    id: 2,
    name: 'Receptionist / Security',
    slug: 'receptionist',
    usersCount: 1,
    description: 'Front desk',
    permissions: ['visits.view_all', 'visits.checkin', 'reports.view'],
  ),
  const Role(
    id: 3,
    name: 'Employee',
    slug: 'employee',
    description: 'Invites own visitors',
    permissions: ['visits.preregister', 'reports.view'],
  ),
]);
final _users = _Repo<AppUser>([
  AppUser(
    id: 9,
    name: 'Abdul Karim (Front Desk)',
    username: 'reception',
    roleId: 2,
    roleName: 'Receptionist / Security',
    branchName: 'Head Office',
    lastLogin: DateTime(2026, 10, 15, 11, 57),
  ),
]);
final _settings = _Settings();

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
      roleRepositoryProvider.overrideWithValue(_roles),
      userRepositoryProvider.overrideWithValue(_users),
      employeeRepositoryProvider.overrideWithValue(_Repo<Employee>([])),
      branchRepositoryProvider.overrideWithValue(_Repo<Branch>([const Branch(id: 1, name: 'Head Office')])),
      permissionCatalogProvider.overrideWith((ref) async => _catalog),
      settingsRepositoryProvider.overrideWithValue(_settings),
    ],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VmsApp()));
  await tester.pumpAndSettle();
  container.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
  return container;
}

Future<void> _end(WidgetTester tester, ProviderContainer c) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  test('user JSON: password only sent when set', () {
    final u = userFromJson({'id': 9, 'name': 'A', 'username': 'reception', 'role_id': 2, 'status': 1});
    expect(userToJson(u).containsKey('password'), isFalse);
    final withPass = AppUser(id: 9, name: 'A', username: 'reception', roleId: 2, password: 'secret1');
    expect(userToJson(withPass)['password'], 'secret1');
  });

  testWidgets('Users: list and add form (password required, receptionist default, role help)', (tester) async {
    final c = await _pump(tester, '/users');
    expect(find.text('Abdul Karim (Front Desk)'), findsOneWidget);
    expect(find.textContaining('@reception · Receptionist / Security'), findsOneWidget);

    await tester.tap(find.text('Add New'));
    await tester.pumpAndSettle();
    expect(find.text('Receptionist / Security'), findsWidgets); // default role
    expect(find.text('Front desk'), findsOneWidget); // role description

    await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'Gate Two');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username *'), 'gate2');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Submit'));
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Password is required'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Password *'), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(_users.saved.last.username, 'gate2');
    expect(_users.saved.last.roleId, 2);
    expect(_users.saved.last.password, 'secret1');
    await _end(tester, c);
  });

  testWidgets('Roles: cards, locked Admin, new role saves permissions in catalog order', (tester) async {
    final c = await _pump(tester, '/roles');
    expect(find.text('Built-in'), findsOneWidget);
    expect(find.textContaining('Full access'), findsOneWidget);
    expect(find.text('3/3'), findsWidgets); // Admin has every visits permission

    // Built-in Admin opens read-only.
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be changed or deleted'), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // New role: no permission -> error; then pick two.
    await tester.tap(find.text('New Role'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Role Name (English) *'), 'Night Guard');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Select at least one permission'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('View reports'), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View reports'));
    await tester.tap(find.text('Gate check-in / check-out'));
    await tester.pump();
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(_roles.saved.last.name, 'Night Guard');
    expect(_roles.saved.last.permissions, ['visits.checkin', 'reports.view']);
    expect(find.text('Role created'), findsOneWidget);
    await _end(tester, c);
  });

  testWidgets('Settings: loads and saves company settings', (tester) async {
    final c = await _pump(tester, '/settings');
    expect(find.text('ABC Group Ltd.'), findsWidgets);
    expect(find.text('Company code: AGL'), findsOneWidget);

    await tester.tap(find.text('Require host approval for pre-registrations'));
    await tester.pump();
    await tester.ensureVisible(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(_settings.saved!.requireApproval, isFalse);
    expect(_settings.saved!.badgeFooter, 'Please return this pass at the reception before leaving.');
    expect(find.text('Settings saved'), findsOneWidget);
    await _end(tester, c);
  });
}
