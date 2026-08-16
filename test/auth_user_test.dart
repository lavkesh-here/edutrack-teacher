// AuthUser.isFeatureDisabled() gates the "restrictable" core-teaching nav
// items (see home.dart's _restrictableFeatureIds / backend
// ALLOWED_DISABLABLE_FEATURES). This is the pure-logic unit under test —
// home.dart's own gating just calls this per-row.

import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_teacher/core/auth.dart';

AuthUser _user({required String role, List<String> disabledFeatures = const []}) => AuthUser(
      teacherName: 'Test Teacher',
      schoolName: 'Test School',
      role: role,
      teacherId: 't1',
      disabledFeatures: disabledFeatures,
    );

void main() {
  group('AuthUser.isFeatureDisabled', () {
    test('false when the feature is not in disabledFeatures', () {
      final u = _user(role: 'teacher', disabledFeatures: ['results']);
      expect(u.isFeatureDisabled('worklog'), false);
    });

    test('true when a plain teacher has the feature disabled', () {
      final u = _user(role: 'teacher', disabledFeatures: ['worklog']);
      expect(u.isFeatureDisabled('worklog'), true);
    });

    test('admin/principal/director are never restricted, even if the list is set', () {
      for (final role in ['admin', 'principal', 'director']) {
        final u = _user(role: role, disabledFeatures: ['worklog', 'health', 'ptm']);
        expect(u.isFeatureDisabled('worklog'), false, reason: '$role must bypass disabled_features');
      }
    });

    test('empty disabledFeatures list disables nothing', () {
      final u = _user(role: 'teacher');
      for (final f in ['worklog', 'notify', 'results', 'syllabus', 'ptm', 'enquiries', 'health']) {
        expect(u.isFeatureDisabled(f), false);
      }
    });
  });

  group('AuthUser.hasTag', () {
    test('true only for tags actually present', () {
      final u = AuthUser(
        teacherName: 'T', schoolName: 'S', role: 'teacher', teacherId: 't1',
        tags: const ['librarian', 'attender'],
      );
      expect(u.hasTag('librarian'), true);
      expect(u.hasTag('attender'), true);
      expect(u.hasTag('hostel_warden'), false);
    });
  });
}
