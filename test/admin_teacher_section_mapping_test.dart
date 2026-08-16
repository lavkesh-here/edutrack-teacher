// Pure logic test for the admin Teacher <-> Class/Section Mapping screen
// (screens/admin_teacher_section_mapping.dart): the client-side search filter
// and the "is this unmapped staff member expected or a real gap" rule.
// Mirrors the private logic in that file 1:1 rather than driving the real
// widget, since it loads data via an ApiClient network call with no mocking
// harness in this repo yet (same pattern as ptm_filters_test.dart).

import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> filterSections(List<Map<String, dynamic>> sections, String search) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return sections;
  return sections.where((s) {
    final label = (s['label'] as String? ?? '').toLowerCase();
    if (label.contains(q)) return true;
    final teachers = (s['teachers'] as List<dynamic>? ?? []);
    return teachers.any((t) => ((t as Map<String, dynamic>)['teacher_name'] as String? ?? '').toLowerCase().contains(q));
  }).toList();
}

bool isExpectedUnmapped(String role, bool isNurse) => role != 'teacher' || isNurse;

void main() {
  final sections = [
    {
      'id': 's1',
      'label': 'Class 5 A',
      'teachers': [
        {'teacher_name': 'Anjali Verma', 'subject_name': 'Mathematics'},
      ],
    },
    {
      'id': 's2',
      'label': 'Class 6 A',
      'teachers': <Map<String, dynamic>>[],
    },
    {
      'id': 's3',
      'label': 'Class 7 A',
      'teachers': [
        {'teacher_name': 'Sanjay Mehta', 'subject_name': 'Science'},
      ],
    },
  ];

  group('Teacher <-> Class Mapping — search filter', () {
    test('empty search returns every section, including ones with no teacher', () {
      expect(filterSections(sections, '').length, 3);
    });

    test('matches by section label', () {
      final result = filterSections(sections, 'class 6');
      expect(result.map((s) => s['id']), ['s2']);
    });

    test('matches by an assigned teacher name, case-insensitive', () {
      final result = filterSections(sections, 'anjali');
      expect(result.map((s) => s['id']), ['s1']);
    });

    test('a section with no teacher never matches a teacher-name search', () {
      final result = filterSections(sections, 'nonexistent teacher');
      expect(result, isEmpty);
    });
  });

  group('Unmapped-staff row — expected vs. real gap', () {
    test('director with no mapping is expected, not a gap', () {
      expect(isExpectedUnmapped('director', false), isTrue);
    });

    test('admin with no mapping is expected, not a gap', () {
      expect(isExpectedUnmapped('admin', false), isTrue);
    });

    test('a nurse-flagged plain teacher with no mapping is expected, not a gap', () {
      expect(isExpectedUnmapped('teacher', true), isTrue);
    });

    test('a plain, non-nurse teacher with no mapping IS a real gap', () {
      expect(isExpectedUnmapped('teacher', false), isFalse);
    });
  });
}
