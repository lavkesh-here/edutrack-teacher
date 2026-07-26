// Regression test for the branding-color bug (bug #8): elements that read
// Theme.of(context).colorScheme.primary — pinned-post borders, the student
// profile header gradient, and 60+ other call sites — must show the EXACT
// brand color the school picked, not Material 3's tonal-palette derivation
// of it (which mutes chroma differently per hue, making some brand colors
// like orange nearly invisible in low-opacity tints while others like
// violet stay vivid).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_teacher/core/theme.dart';

void main() {
  group('buildColorScheme primary pinning', () {
    test('colorScheme.primary equals the exact seed color, not a derived tone', () {
      const seeds = [
        Color(0xFFF97316), // orange — the app default
        Color(0xFF8B5CF6), // violet preset
        Color(0xFF14B8A6), // teal preset
        Color(0xFF22C55E), // green preset
        Color(0xFFF43F5E), // rose preset
      ];
      for (final seed in seeds) {
        final scheme = buildColorScheme(seed);
        // Sanity check the bug this test guards against: Material 3's own
        // derivation (without the .copyWith pin) drifts from the seed.
        final derivedOnly = ColorScheme.fromSeed(seedColor: seed, surface: AppColors.bg);
        expect(derivedOnly.primary, isNot(equals(seed)),
            reason: 'if fromSeed ever starts returning the exact seed, the .copyWith pin becomes redundant (harmless) — update this test');

        expect(scheme.primary, equals(seed),
            reason: 'colorScheme.primary must match the raw branding color exactly for $seed');
      }
    });

    test('default AppColors.sun is preserved by the pin', () {
      final scheme = buildColorScheme(AppColors.sun);
      expect(scheme.primary, equals(AppColors.sun));
    });
  });
}
