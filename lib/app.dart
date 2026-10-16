import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';

class VmsApp extends ConsumerWidget {
  const VmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: const Color(0xFF006A4E))),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => _BottomSystemBarInset(child: child!),
    );
  }
}

/// Android 15+ draws apps edge-to-edge (Android 16 no longer allows opting out), so the
/// navigation bar covers the bottom of every page, drawer, sheet and dialog. Keep all
/// content above it, once for the whole app, and paint the strip behind it.
/// The top (status bar) is left to the AppBars, which already handle it.
class _BottomSystemBarInset extends StatelessWidget {
  const _BottomSystemBarInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      // While the keyboard is open the bar is behind it (padding.bottom == 0), so forms
      // sit directly on the keyboard without an extra gap.
      child: SafeArea(top: false, left: false, right: false, child: child),
    );
  }
}
