import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vms_app/app.dart';
import 'package:vms_app/core/error/failures.dart';
import 'package:vms_app/core/storage/storage_providers.dart';
import 'package:vms_app/core/utils/result.dart';
import 'package:vms_app/features/auth/domain/entities/user.dart';
import 'package:vms_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vms_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vms_app/features/dashboard/presentation/providers/dashboard_providers.dart';

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

class _FakeAuth extends AuthNotifier {
  @override
  Future<User?> build() async => _admin;
}

class _OfflineDashboard implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(const Error<Never>(NetworkFailure()));
}

void main() {
  // Android 15+ draws apps edge-to-edge: the 3-button navigation bar overlaps the
  // bottom of the window (reported as view padding). Nothing may be drawn under it.
  testWidgets('drawer Logout stays above the Android navigation bar', (tester) async {
    const navBar = 48.0;
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 32 * 3, bottom: navBar * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 32 * 3, bottom: navBar * 3);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_FakeAuth.new),
        dashboardRepositoryProvider.overrideWithValue(_OfflineDashboard()),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VmsApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // Header shows the username under the name.
    expect(find.text('@admin'), findsOneWidget);

    final logout = tester.getRect(find.text('Logout'));
    expect(logout.bottom, lessThanOrEqualTo(780 - navBar), reason: 'Logout is hidden behind the navigation bar');

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
