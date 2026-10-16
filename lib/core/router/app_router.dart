import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/shell/presentation/pages/coming_soon_page.dart';
import 'app_routes.dart';

export 'app_routes.dart';

/// Pages that are built. Every other menu item shows [ComingSoonPage].
final Map<String, WidgetBuilder> _pages = {
  AppRoutes.dashboard: (_) => const DashboardPage(),
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
          builder: (context, _) =>
              _pages[item.route]?.call(context) ?? ComingSoonPage(title: item.label),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
