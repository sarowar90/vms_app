// Draws the VMS app icon PNGs (same brand mark as the web sidebar: a white ID badge
// on Bangladesh green with a red accent).
//
// Regenerate:  flutter test tool/generate_app_icon.dart
// Then:        dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _green = Color(0xFF006A4E);
const _greenDark = Color(0xFF00523C);
const _red = Color(0xFFF42A41);
const _size = 1024.0;

void main() {
  test('generate app icon PNGs', () async {
    // Full icon (iOS, legacy Android, store listing): green tile filling the square.
    await _write('assets/icon/app_icon.png', (c) {
      c.drawRect(const Rect.fromLTWH(0, 0, _size, _size), Paint()..color = _green);
      _badge(c, scale: 0.62);
    });
    // Android adaptive foreground: transparent, badge kept inside the 66% safe zone
    // (the launcher crops to its own circle / squircle and adds the green background).
    await _write('assets/icon/app_icon_foreground.png', (c) => _badge(c, scale: 0.46));
  });
}

/// White ID badge with clip, person and text lines, plus the red accent bar under it.
void _badge(Canvas c, {required double scale}) {
  final s = _size * scale; // badge height
  final w = s * 0.78;
  final left = (_size - w) / 2;
  final top = (_size - s) / 2 - s * 0.04;
  final white = Paint()..color = Colors.white;
  final green = Paint()..color = _green;

  // Card.
  final card = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, s), Radius.circular(s * 0.11));
  c.drawRRect(card, white);

  // Lanyard clip slot at the top.
  final slotW = w * 0.30;
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(left + (w - slotW) / 2, top + s * 0.07, slotW, s * 0.065),
      Radius.circular(s * 0.04),
    ),
    Paint()..color = _greenDark,
  );

  // Person: head + shoulders.
  final cx = left + w / 2;
  c.drawCircle(Offset(cx, top + s * 0.37), s * 0.12, green);
  final shoulders = Path()
    ..moveTo(cx - s * 0.22, top + s * 0.70)
    ..quadraticBezierTo(cx - s * 0.22, top + s * 0.51, cx, top + s * 0.51)
    ..quadraticBezierTo(cx + s * 0.22, top + s * 0.51, cx + s * 0.22, top + s * 0.70)
    ..close();
  c.drawPath(shoulders, green);

  // Name / detail lines.
  final lineH = s * 0.045;
  for (final (y, frac) in [(0.77, 0.56), (0.86, 0.38)]) {
    final lw = w * frac;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - lw / 2, top + s * y, lw, lineH), Radius.circular(lineH / 2)),
      Paint()..color = _green.withValues(alpha: 0.55),
    );
  }

  // Red accent bar (web: inset red bottom border of the brand icon).
  final barW = w * 0.70;
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - barW / 2, top + s + s * 0.07, barW, s * 0.07),
      Radius.circular(s * 0.035),
    ),
    Paint()..color = _red,
  );
}

Future<void> _write(String path, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder, const Rect.fromLTWH(0, 0, _size, _size)));
  final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}
