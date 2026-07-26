// Regression test for the feature-flag parity gap: the "Features & Plan"
// section only listed 8 of the backend's 22 teacher feature keys (and 5 of 6
// parent keys, missing brain_booster) — so an admin disabling a feature not
// in the mobile list had no way to see or re-enable it from the app. This
// pins the mobile key sets to backend `_ALL_FEATURES`
// (app/api/v1/endpoints/admin/school.py) so future backend additions get
// caught here instead of silently drifting again.
import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_teacher/screens/admin_school_settings.dart';

// Mirrors backend _ALL_FEATURES in app/api/v1/endpoints/admin/school.py.
const _backendTeacherKeys = {
  'feature.announcements', 'feature.circulars', 'feature.work_logs',
  'feature.transport', 'feature.syllabus', 'feature.todo',
  'feature.tests', 'feature.payroll', 'feature.parent_fees',
  'feature.ai_generate', 'feature.attendance_analytics',
  'feature.operational_dashboard', 'feature.pdf_export',
  'feature.ai_analysis', 'feature.diksha', 'feature.visitor_log',
  'feature.analytics_dashboard', 'feature.online_fees',
  'feature.spaced_repetition', 'feature.color_theme',
  'feature.library', 'feature.brain_booster',
};

const _backendParentKeys = {
  'feature.parent_fees', 'feature.transport',
  'feature.circulars', 'feature.work_logs', 'feature.announcements',
  'feature.brain_booster',
};

void main() {
  group('Feature flag mobile/backend parity', () {
    test('teacher feature list covers every backend teacher key', () {
      final mobileKeys = teacherFeatureDefs.map((f) => f.$1).toSet();
      expect(mobileKeys, equals(_backendTeacherKeys));
    });

    test('parent feature list covers every backend parent key', () {
      final mobileKeys = parentFeatureDefs.map((f) => f.$1).toSet();
      expect(mobileKeys, equals(_backendParentKeys));
    });

    test('no duplicate keys within a role list', () {
      final teacherKeys = teacherFeatureDefs.map((f) => f.$1).toList();
      final parentKeys = parentFeatureDefs.map((f) => f.$1).toList();
      expect(teacherKeys.toSet().length, teacherKeys.length);
      expect(parentKeys.toSet().length, parentKeys.length);
    });
  });
}
