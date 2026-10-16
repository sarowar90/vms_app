import 'package:flutter/material.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, required this.child, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: title,
                      style: theme.textTheme.titleSmall,
                      children: [
                        if (subtitle != null)
                          TextSpan(
                            text: '  ($subtitle)',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                      ],
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
