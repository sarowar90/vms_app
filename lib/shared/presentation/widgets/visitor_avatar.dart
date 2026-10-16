import 'package:flutter/material.dart';

/// Visitor photo, or initials when there is none.
class VisitorAvatar extends StatelessWidget {
  const VisitorAvatar({super.key, required this.name, this.photoUrl, this.radius = 20});

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      foregroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: Text(initials, style: TextStyle(fontSize: radius * 0.7)),
    );
  }
}
