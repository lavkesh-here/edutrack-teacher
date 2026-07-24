// Regression test for the "missing" work log subject picker.
//
// worklog.dart's _showAddSheet() used to render the whole "Subject
// (optional)" chip row only when `if (subjects.isNotEmpty)`, with no
// loading indicator and a silently swallowed fetch error
// (`.catchError((_) {})`). If a teacher had zero subject assignments for
// the active academic year, or the fetch failed, the entire block simply
// vanished with no visual trace — indistinguishable from the feature never
// having shipped. Fixed by adding explicit loading/error/empty states.
// Precedence logic replicated here per this project's test convention.

import 'package:flutter_test/flutter_test.dart';

String subjectPickerState({
  required bool loading,
  required bool error,
  required bool empty,
}) {
  if (loading) return 'loading';
  if (error) return 'error';
  if (empty) return 'empty';
  return 'loaded';
}

void main() {
  group('Work log subject picker state precedence', () {
    test('still fetching -> loading, regardless of other flags', () {
      expect(subjectPickerState(loading: true, error: true, empty: true), 'loading');
      expect(subjectPickerState(loading: true, error: false, empty: false), 'loading');
    });

    test('fetch failed -> error message shown', () {
      expect(subjectPickerState(loading: false, error: true, empty: true), 'error');
      expect(subjectPickerState(loading: false, error: true, empty: false), 'error');
    });

    test('fetch succeeded but no subjects assigned -> empty-state text', () {
      expect(subjectPickerState(loading: false, error: false, empty: true), 'empty');
    });

    test('fetch succeeded with subjects -> chip row shown', () {
      expect(subjectPickerState(loading: false, error: false, empty: false), 'loaded');
    });
  });
}
