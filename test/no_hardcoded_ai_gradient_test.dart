// Regression guard for a recurring pattern (per user feedback, fixed multiple
// times already): new "AI feature" cards/buttons keep getting a copy-pasted
// hardcoded dark-orange gradient (Color(0xFF1A0A00) -> Color(0xFF3D1A08))
// instead of deriving their color from the school's theme (context.primary).
// This bug was found and fixed in test_scores.dart and profile.dart on the
// same day it was reported — this test scans every screen source file so a
// future copy-paste of the same hardcoded pair fails CI immediately instead
// of shipping to a school with a mismatched brand color.
//
// Pure logic test — reads source files from disk, no device required.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no screen hardcodes the old non-themed AI-card gradient colors', () {
    final screensDir = Directory('lib/screens');
    expect(screensDir.existsSync(), isTrue,
        reason: 'Run this test from the teacher_app package root.');

    final offenders = <String>[];
    for (final entity in screensDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      if (content.contains('0xFF1A0A00') || content.contains('0xFF3D1A08')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Found hardcoded AI-card gradient colors in: ${offenders.join(', ')}. '
          'Use context.primary (and Color.lerp(context.primary, Colors.black, ...) '
          'for a darker shade) instead, so the color follows each school\'s theme.',
    );
  });
}
