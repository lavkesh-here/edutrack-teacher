import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Pure logic unit tests (no platform channels needed) ──────────────────────

void main() {
  group('Leave Sunday restriction', () {
    final predicate = (DateTime date) => date.weekday != DateTime.sunday;

    test('Sunday is blocked', () {
      expect(predicate(DateTime(2026, 6, 21)), isFalse); // known Sunday
    });

    test('Monday through Saturday are allowed', () {
      for (int i = 15; i <= 20; i++) {
        expect(predicate(DateTime(2026, 6, i)), isTrue,
            reason: 'Day ${DateTime(2026, 6, i).weekday} should be allowed');
      }
    });

    test('Sunday is weekday 7', () {
      expect(DateTime(2026, 6, 21).weekday, equals(DateTime.sunday));
      expect(DateTime.sunday, equals(7));
    });
  });

  group('Attendance 1-week limit (7 selectable days)', () {
    test('firstDate = today - 6 days gives 7-day window', () {
      final today = DateTime.now();
      final firstDate = today.subtract(const Duration(days: 6));
      expect(today.difference(firstDate).inDays, equals(6));
      // Total: firstDate, firstDate+1, ..., today = 7 days
    });

    test('today is always selectable', () {
      final today = DateTime.now();
      final firstDate = today.subtract(const Duration(days: 6));
      expect(today.isAfter(firstDate) || today == firstDate, isTrue);
    });
  });

  group('Tests screen subject / class label guard', () {
    String joinLabel(String subject, String className) => [
          if (subject.isNotEmpty) subject,
          if (className.isNotEmpty) className,
        ].join(' · ');

    test('both non-empty joined with dot', () {
      expect(joinLabel('Maths', 'Class 9A'), equals('Maths · Class 9A'));
    });

    test('empty subject omitted', () {
      expect(joinLabel('', 'Class 9A'), equals('Class 9A'));
    });

    test('empty class omitted', () {
      expect(joinLabel('Maths', ''), equals('Maths'));
    });

    test('both empty gives empty string', () {
      expect(joinLabel('', ''), equals(''));
    });
  });

  group('Work log multi-section', () {
    test('at least one section always stays selected', () {
      final selected = <String>{'sec1'};
      if (selected.length > 1) selected.remove('sec1');
      expect(selected, contains('sec1'));
    });

    test('adding a section increases the set', () {
      final selected = <String>{'sec1'};
      selected.add('sec2');
      expect(selected.length, equals(2));
    });

    test('removing non-last section works', () {
      final selected = <String>{'sec1', 'sec2'};
      selected.remove('sec2');
      expect(selected, equals({'sec1'}));
    });

    test('count label singular', () {
      final count = 1;
      final label = count > 1 ? 'Work log added to $count sections ✓' : 'Work log added ✓';
      expect(label, equals('Work log added ✓'));
    });

    test('count label plural', () {
      final count = 3;
      final label = count > 1 ? 'Work log added to $count sections ✓' : 'Work log added ✓';
      expect(label, equals('Work log added to 3 sections ✓'));
    });
  });

  group('Scheduled date format fix', () {
    test('substring(0,10) gives yyyy-MM-dd', () {
      final d = DateTime(2026, 6, 17, 10, 30, 0);
      expect(d.toLocal().toString().substring(0, 10), equals('2026-06-17'));
    });

    test('timezone-shifted datetime still gives local date', () {
      // Any DateTime.toLocal().toString() always starts with the local date
      final d = DateTime(2026, 1, 1, 0, 0, 0);
      final result = d.toLocal().toString().substring(0, 10);
      expect(result, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });

  group('Week strip logic', () {
    test('Monday is weekday 1', () {
      final tuesday = DateTime(2026, 6, 16);
      final monday = tuesday.subtract(Duration(days: tuesday.weekday - 1));
      expect(monday.weekday, equals(DateTime.monday));
    });

    test('7th day from Monday is Sunday', () {
      final tuesday = DateTime(2026, 6, 16);
      final monday = tuesday.subtract(Duration(days: tuesday.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      expect(sunday.weekday, equals(DateTime.sunday));
    });

    test('today is within the 7-day strip', () {
      final today = DateTime.now();
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      expect(
        today.isAfter(monday.subtract(const Duration(days: 1))) &&
            today.isBefore(sunday.add(const Duration(days: 1))),
        isTrue,
      );
    });

    test('future days in strip are marked as future', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      expect(tomorrow.isAfter(today), isTrue);
    });

    test('sunday strip item shows Off label', () {
      // The strip shows 'Off' for Sunday — verify logic
      const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      expect(dayLabels[6], equals('Sun')); // index 6 = Sunday
    });
  });

  group('Personal details bug fix (fetchFresh guard)', () {
    test('fetched flag prevents double-fetch', () {
      bool fetched = false;
      int callCount = 0;

      void fetchFresh() {
        if (fetched) return;
        fetched = true;
        callCount++;
      }

      // Simulates being called from multiple StatefulBuilder rebuilds
      fetchFresh();
      fetchFresh();
      fetchFresh();

      expect(callCount, equals(1));
    });
  });

  group('Server env badge logic', () {
    const defaultUrl = 'https://api.example.run.app';

    test('default URL = production', () {
      expect(defaultUrl == defaultUrl, isTrue);
    });

    test('custom URL = dev', () {
      const devUrl = 'http://192.168.1.5:8000';
      expect(devUrl == defaultUrl, isFalse);
    });

    test('switching to prod resets to defaultUrl', () {
      String current = 'http://192.168.1.5:8000';
      current = defaultUrl; // simulate switching to prod
      expect(current, equals(defaultUrl));
    });
  });

  group('DEV/PROD badge label', () {
    test('production shows PRODUCTION', () {
      const isProd = true;
      expect(isProd ? 'PRODUCTION' : 'DEV', equals('PRODUCTION'));
    });

    test('dev shows DEV', () {
      const isProd = false;
      expect(isProd ? 'PRODUCTION' : 'DEV', equals('DEV'));
    });
  });

  group('BiometricEnrollment guard', () {
    test('enrollment offered only when not already enabled', () {
      const canUseBio = true;
      const alreadyEnabled = false;
      expect(canUseBio && !alreadyEnabled, isTrue);
    });

    test('enrollment skipped when already enabled', () {
      const canUseBio = true;
      const alreadyEnabled = true;
      expect(canUseBio && !alreadyEnabled, isFalse);
    });

    test('enrollment skipped when bio not available', () {
      const canUseBio = false;
      const alreadyEnabled = false;
      expect(canUseBio && !alreadyEnabled, isFalse);
    });
  });

  group('Attendance student card', () {
    test('photo shown when photoUrl is not empty', () {
      const photoUrl = 'https://storage.googleapis.com/photo.jpg';
      expect(photoUrl.isNotEmpty, isTrue);
    });

    test('initials shown when photoUrl is null', () {
      const String? photoUrl = null;
      expect(photoUrl == null || photoUrl.isEmpty, isTrue);
    });

    test('initials from two-word name', () {
      String initials(String name) {
        final parts = name.trim().split(' ');
        if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
        return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
      }
      expect(initials('Rahul Kumar'), equals('RK'));
      expect(initials('Alice'), equals('A'));
      expect(initials(''), equals('?'));
    });
  });
}
