// Regression tests for the Visitor Log screen fixes:
//   - check-in/check-out timestamps used to render as bare "HH:MM", making
//     entries from different days indistinguishable once date-range
//     filtering was added.
//   - the visitor list query needs to build up to three optional params
//     (date_from, date_to, visit_type) without leaving stray "&" separators
//     when some are omitted.
// Logic replicated here per this project's test convention (see
// worklog_subject_picker_test.dart) rather than pumping the full widget
// tree, since these are pure formatting/string-building concerns.
import 'package:flutter_test/flutter_test.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]}, $h:$m';
  } catch (_) {
    return iso;
  }
}

String buildVisitorsQuery({String? dateFrom, String? dateTo, String? visitType}) {
  final params = <String>[];
  if (dateFrom != null) params.add('date_from=$dateFrom');
  if (dateTo != null) params.add('date_to=$dateTo');
  if (visitType != null && visitType.isNotEmpty) params.add('visit_type=$visitType');
  return params.isEmpty ? '' : '?${params.join('&')}';
}

void main() {
  group('Visitor date+time formatting', () {
    test('includes day and month, not just time', () {
      final result = formatDateTime('2026-05-01T09:30:00Z');
      expect(result, contains('May'));
      expect(result, isNot(matches(r'^\d{2}:\d{2}$')));
    });

    test('null or empty input renders a placeholder', () {
      expect(formatDateTime(null), '—');
      expect(formatDateTime(''), '—');
    });
  });

  group('Visitors list query building', () {
    test('no filters produces an empty query string', () {
      expect(buildVisitorsQuery(), '');
    });

    test('single filter has no stray separators', () {
      expect(buildVisitorsQuery(dateFrom: '2026-05-01'), '?date_from=2026-05-01');
    });

    test('all three filters join with & in order', () {
      expect(
        buildVisitorsQuery(dateFrom: '2026-05-01', dateTo: '2026-05-31', visitType: 'vendor'),
        '?date_from=2026-05-01&date_to=2026-05-31&visit_type=vendor',
      );
    });

    test('empty-string visit type is treated as unset', () {
      expect(buildVisitorsQuery(dateFrom: '2026-05-01', visitType: ''), '?date_from=2026-05-01');
    });
  });
}
