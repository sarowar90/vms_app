import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/blacklist/domain/blacklist_repository.dart';
import '../../features/blacklist/presentation/pages/blacklist_page.dart';
import '../../features/inside/presentation/pages/inside_page.dart';
import '../../features/masters/presentation/pages/master_pages.dart';
import '../../features/masters/presentation/pages/roles_pages.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/reports/presentation/pages/report_page.dart';
import '../../features/visitors/presentation/pages/visitors_page.dart';
import '../../features/visits/presentation/pages/all_visits_page.dart';
import '../../shared/domain/entities/visit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/checkin/presentation/pages/checkin_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/preregister/presentation/pages/preregister_page.dart';
import '../../features/shell/presentation/pages/coming_soon_page.dart';
import 'app_routes.dart';

export 'app_routes.dart';

/// Pages that are built. Every other menu item shows [ComingSoonPage].
final Map<String, Widget Function(GoRouterState state)> _pages = {
  AppRoutes.dashboard: (_) => const DashboardPage(),
  // /checkin?visit=ID opens the Pre-registered tab with that visit.
  AppRoutes.checkin: (s) =>
      CheckinPage(key: ValueKey(s.uri.query), visitId: int.tryParse(s.uri.queryParameters['visit'] ?? '')),
  // /preregister?new=1 opens the new pre-registration form.
  AppRoutes.preregister: (s) => PreregisterPage(openNew: s.uri.queryParameters['new'] == '1'),
  // /visits?status=pending pre-selects a status chip.
  AppRoutes.visits: (s) => AllVisitsPage(
    key: ValueKey(s.uri.query),
    initialStatus: switch (s.uri.queryParameters['status']) {
      final v? => VisitStatus.fromValue(v),
      null => null,
    },
  ),
  AppRoutes.active: (_) => const InsidePage(),
  AppRoutes.reports: (_) => const ReportPage(),
  AppRoutes.branches: (_) => const BranchesPage(),
  AppRoutes.departments: (_) => const DepartmentsPage(),
  AppRoutes.employees: (_) => const EmployeesPage(),
  AppRoutes.users: (_) => const UsersPage(),
  AppRoutes.roles: (_) => const RolesPage(),
  AppRoutes.settings: (_) => const SettingsPage(),
  AppRoutes.visitors: (_) => const VisitorsPage(),
  // /blacklist?phone=&name=&id_number= opens the add form pre-filled (from a visitor profile).
  AppRoutes.blacklist: (s) {
    final q = s.uri.queryParameters;
    return BlacklistPage(
      key: ValueKey(s.uri.query),
      prefill: q['phone'] == null && q['id_number'] == null
          ? null
          : BlacklistInput(name: q['name'], phone: q['phone'], idNumber: q['id_number'], reason: ''),
    );
  },
};

final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the session changes, without rebuilding the router.
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;

      if (auth.isLoading && !auth.hasValue) return AppRoutes.splash;

      final user = auth.value;
      if (user == null) return location == AppRoutes.login ? null : AppRoutes.login;

      // Same rules as the web: super admin only manages companies;
      // company users only open pages their permissions allow.
      final menu = user.isSuperAdmin ? superAdminNav : companyNav;
      final home = menu.first.route;
      final item = menu.where((i) => i.route == location).firstOrNull;
      if (item == null || !user.canAny(item.permissions)) return home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      for (final item in [...superAdminNav, ...companyNav])
        GoRoute(
          path: item.route,
          builder: (_, state) => _pages[item.route]?.call(state) ?? ComingSoonPage(title: item.label),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
