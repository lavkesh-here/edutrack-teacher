// Pure logic test for the PTM search/filter feature (screens/ptm.dart):
//   1. PTMScreen's event list -- text search (name/description) + month filter.
//   2. PTMEventDetail's meeting/registration lists -- student-name search +
//      class/section filter.
// Mirrors the private filtering logic in ptm.dart 1:1 rather than driving the
// real widgets, since those load data via ApiClient network calls with no
// mocking harness in this repo yet (same pattern as staff_directory_parsing_test.dart).

import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> filterEvents(
  List<Map<String, dynamic>> events, {
  required String search,
  String? monthFilter,
}) {
  final q = search.trim().toLowerCase();
  return events.where((e) {
    if (monthFilter != null) {
      final iso = e['event_date'] as String?;
      if (iso == null || !iso.startsWith(monthFilter)) return false;
    }
    if (q.isEmpty) return true;
    final name = (e['name'] as String? ?? '').toLowerCase();
    final desc = (e['description'] as String? ?? '').toLowerCase();
    return name.contains(q) || desc.contains(q);
  }).toList();
}

bool matchesStudentFilters(
  Map<String, dynamic> row, {
  required String studentSearch,
  String? sectionFilter,
}) {
  if (sectionFilter != null && row['section_label'] != sectionFilter) return false;
  final q = studentSearch.trim().toLowerCase();
  if (q.isEmpty) return true;
  final name = (row['student_name'] as String? ?? '').toLowerCase();
  return name.contains(q);
}

void main() {
  final events = [
    {'id': '1', 'name': 'Q1 Parent Teacher Meeting', 'description': 'Term 1 progress review', 'event_date': '2026-08-10'},
    {'id': '2', 'name': 'Sports Day Feedback PTM', 'description': null, 'event_date': '2026-08-25'},
    {'id': '3', 'name': 'Annual PTM', 'description': 'Full year review', 'event_date': '2026-09-15'},
  ];

  group('PTM event list — search + month filter', () {
    test('no filters returns everything', () {
      expect(filterEvents(events, search: '').length, 3);
    });

    test('search matches event name, case-insensitive', () {
      final result = filterEvents(events, search: 'sports');
      expect(result.map((e) => e['id']), ['2']);
    });

    test('search matches description too', () {
      final result = filterEvents(events, search: 'full year');
      expect(result.map((e) => e['id']), ['3']);
    });

    test('null description does not throw when searching', () {
      expect(() => filterEvents(events, search: 'anything'), returnsNormally);
    });

    test('month filter narrows to that YYYY-MM only', () {
      final result = filterEvents(events, search: '', monthFilter: '2026-08');
      expect(result.map((e) => e['id']).toSet(), {'1', '2'});
    });

    test('search and month filter combine (AND, not OR)', () {
      final result = filterEvents(events, search: 'ptm', monthFilter: '2026-09');
      expect(result.map((e) => e['id']), ['3']);
    });

    test('no matches returns empty, not an error', () {
      expect(filterEvents(events, search: 'nonexistent event'), isEmpty);
    });
  });

  group('PTM event detail — student search + class/section filter', () {
    final rows = [
      {'student_id': 's1', 'student_name': 'Arjun Mehta', 'section_label': 'Class 5 A'},
      {'student_id': 's2', 'student_name': 'Priya Patel', 'section_label': 'Class 6 A'},
      {'student_id': 's3', 'student_name': 'Arjun Kumar', 'section_label': 'Class 6 A'},
    ];

    test('no filters matches every row', () {
      final matched = rows.where((r) => matchesStudentFilters(r, studentSearch: '')).toList();
      expect(matched.length, 3);
    });

    test('student-name search is a case-insensitive substring match', () {
      final matched = rows.where((r) => matchesStudentFilters(r, studentSearch: 'arjun')).toList();
      expect(matched.map((r) => r['student_id']).toSet(), {'s1', 's3'});
    });

    test('class/section filter narrows to that exact section', () {
      final matched = rows.where((r) => matchesStudentFilters(r, studentSearch: '', sectionFilter: 'Class 6 A')).toList();
      expect(matched.map((r) => r['student_id']).toSet(), {'s2', 's3'});
    });

    test('name search and section filter combine (AND, not OR)', () {
      final matched = rows
          .where((r) => matchesStudentFilters(r, studentSearch: 'arjun', sectionFilter: 'Class 6 A'))
          .toList();
      expect(matched.map((r) => r['student_id']), ['s3']);
    });
  });
}
