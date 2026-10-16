import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';

/// Placeholder for menu items whose feature is not built yet.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: const AppDrawer(),
      body: Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(Icons.construction, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('$title is coming soon', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
