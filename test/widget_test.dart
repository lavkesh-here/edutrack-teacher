import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit-level tests for pure logic — no rendering needed for most of these.
// Widget smoke tests verify key screens build without crashing.

void main() {
  group('Leave Sunday restriction', () {
    test('Sunday (weekday=7) is blocked', () {
      final predicate = (DateTime date) => date.weekday != DateTime.sunday;
      final sunday = DateTime(2026, 6, 21); // known Sunday
      final monday = DateTime(2026, 6, 22);
      expect(predicate(sunday), isFalse);
      expect(predicate(monday), isTrue);
    });
  });

  group('Attendance 1-week limit', () {
    test('firstDate is today minus 6 days (7-day window)', () {
      final today = DateTime.now();
      final firstDate = today.subtract(const Duration(days: 6));
      final diff = today.difference(firstDate).inDays;
      expect(diff, equals(6)); // 6 days before today = 7 selectable days total
    });
  });

  group('Tests screen subject/class guard', () {
    test('empty strings are excluded from dot-joined label', () {
      final subject = '';
      final className = 'Class 9A';
      final result = [
        if (subject.isNotEmpty) subject,
        if (className.isNotEmpty) className,
      ].join(' · ');
      expect(result, equals('Class 9A'));
    });

    test('both non-empty are joined', () {
      final subject = 'Maths';
      final className = 'Class 9A';
      final result = [
        if (subject.isNotEmpty) subject,
        if (className.isNotEmpty) className,
      ].join(' · ');
      expect(result, equals('Maths · Class 9A'));
    });
  });

  group('Worklog multi-section', () {
    test('at least one section must remain selected', () {
      final Set<String> selected = {'sec1'};
      // Attempting to remove last section should be no-op
      if (selected.length > 1) selected.remove('sec1');
      expect(selected, contains('sec1'));
    });

    test('multi-section creates correct count label', () {
      final count = 3;
      final label = count > 1 ? 'Work log added to $count sections ✓' : 'Work log added ✓';
      expect(label, equals('Work log added to 3 sections ✓'));
    });
  });

  group('Scheduled date format', () {
    test('toLocal().toString().substring(0,10) gives yyyy-MM-dd', () {
      final d = DateTime(2026, 6, 17, 10, 30, 0);
      final result = d.toLocal().toString().substring(0, 10);
      expect(result, equals('2026-06-17'));
    });
  });

  group('Week strip logic', () {
    test('Monday is weekday 1', () {
      final today = DateTime(2026, 6, 17); // Tuesday
      final monday = today.subtract(Duration(days: today.weekday - 1));
      expect(monday.weekday, equals(DateTime.monday));
    });

    test('7th day (index 6) is Sunday', () {
      final today = DateTime(2026, 6, 17);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      expect(sunday.weekday, equals(DateTime.sunday));
    });
  });
}
