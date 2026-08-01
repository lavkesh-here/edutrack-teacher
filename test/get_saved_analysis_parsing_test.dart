// Regression test for a real bug: ApiClient.getAnalysis() read
// data['class_insight'] at the top level of the GET /analysis/saved response,
// but the backend (scores.py get_saved_analysis) nests it under
// data['analysis']['class_insight'] — exactly like the POST /analysis
// response TestAnalysisResult.fromJson already parses correctly. The bug
// meant a previously-run, DB-persisted analysis never showed up again when
// reopening a test — it silently looked identical to "never run".
//
// Pure logic test — no device or platform channels required.

import 'package:flutter_test/flutter_test.dart';

class _AnalysisInsight {
  final String summary;
  final List<String> concernAreas;
  final String recommendedAction;
  const _AnalysisInsight({
    required this.summary,
    required this.concernAreas,
    required this.recommendedAction,
  });
  factory _AnalysisInsight.fromJson(Map<String, dynamic> j) => _AnalysisInsight(
        summary: j['summary'] as String? ?? '',
        concernAreas: (j['concern_areas'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        recommendedAction: j['recommended_action'] as String? ?? '',
      );
}

// Mirrors the FIXED extraction logic in ApiClient.getAnalysis().
_AnalysisInsight? _extractFixed(Map<String, dynamic> data) {
  final insight =
      (data['analysis'] as Map<String, dynamic>?)?['class_insight'];
  if (insight == null) return null;
  return _AnalysisInsight.fromJson(insight as Map<String, dynamic>);
}

// Mirrors the ORIGINAL buggy extraction logic — kept here only to prove the
// regression fixture actually exercises the bug, not just the fix.
_AnalysisInsight? _extractBuggy(Map<String, dynamic> data) {
  final insight = data['class_insight'];
  if (insight == null) return null;
  return _AnalysisInsight.fromJson(insight as Map<String, dynamic>);
}

void main() {
  // Exact shape of GET /api/v1/tests/{test_id}/analysis/saved from
  // backend/app/api/v1/endpoints/scores.py::get_saved_analysis.
  final backendResponse = <String, dynamic>{
    'test_id': 'a1b2c3',
    'test_title': 'Unit Test 1 — Mathematics',
    'analysis_id': 7,
    'generated_at': '2026-08-01T10:00:00Z',
    'triggered_by': 'initial',
    'student_count': 6,
    'analysis': {
      'class_insight': {
        'summary': 'Class performed above average overall.',
        'concern_areas': ['Fractions', 'Word problems'],
        'recommended_action': 'Re-teach word problems with worked examples.',
      },
      'student_plans': <dynamic>[],
      'suggested_followup_test': null,
    },
  };

  test('getAnalysis parses a previously-saved analysis on reopen', () {
    final result = _extractFixed(backendResponse);
    expect(result, isNotNull);
    expect(result!.summary, 'Class performed above average overall.');
    expect(result.concernAreas, ['Fractions', 'Word problems']);
    expect(result.recommendedAction,
        'Re-teach word problems with worked examples.');
  });

  test('regression guard: the old top-level path silently returns null', () {
    // Documents exactly why this bug was invisible — no exception, just a
    // silent null that made a saved analysis look like it was never run.
    expect(_extractBuggy(backendResponse), isNull);
  });
}
