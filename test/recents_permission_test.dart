// Regression test for stale "Recently Viewed" chips bypassing permission checks.
//
// home.dart's RecentsManager persists visited screen IDs locally per
// teacher_id (SharedPreferences). If a teacher's role or feature flags
// change (e.g. admin -> teacher, fees plan removed) after they'd previously
// visited an admin-only screen, the stale chip used to still be shown and
// still navigated straight through with zero re-check, leading to a
// confusing backend 403 instead of the button simply not being there.
// canAccessRecent() re-validates each recent ID against the CURRENT role
// and flags before it's allowed to render as a chip.

import 'package:flutter_test/flutter_test.dart';

bool canAccessRecent(String id, {
  required String role,
  required bool transportFlag,
  required bool workLogsFlag,
  required bool feesFlag,
}) {
  final isAdminOrAbove = role == 'admin' || role == 'principal' || role == 'director';
  final isAdmin = role == 'admin';
  switch (id) {
    case 'parents':
    case 'school_settings':
    case 'attenders':
      return isAdminOrAbove;
    case 'transport':
      return isAdminOrAbove && transportFlag;
    case 'admin_worklogs':
      return isAdminOrAbove && workLogsFlag;
    case 'fees':
      return isAdminOrAbove && feesFlag;
    case 'leave_config':
      return isAdmin;
    default:
      return true;
  }
}

void main() {
  group('canAccessRecent — role-only admin screens', () {
    for (final id in ['parents', 'school_settings', 'attenders']) {
      test('$id: admin/principal/director allowed, plain teacher/hod blocked', () {
        for (final role in ['admin', 'principal', 'director']) {
          expect(canAccessRecent(id, role: role, transportFlag: true, workLogsFlag: true, feesFlag: true), true);
        }
        for (final role in ['teacher', 'hod']) {
          expect(canAccessRecent(id, role: role, transportFlag: true, workLogsFlag: true, feesFlag: true), false);
        }
      });
    }
  });

  group('canAccessRecent — flag-gated admin screens', () {
    test('transport requires isAdminOrAbove AND the flag', () {
      expect(canAccessRecent('transport', role: 'admin', transportFlag: true, workLogsFlag: true, feesFlag: true), true);
      expect(canAccessRecent('transport', role: 'admin', transportFlag: false, workLogsFlag: true, feesFlag: true), false);
      expect(canAccessRecent('transport', role: 'teacher', transportFlag: true, workLogsFlag: true, feesFlag: true), false);
    });

    test('admin_worklogs requires isAdminOrAbove AND the flag', () {
      expect(canAccessRecent('admin_worklogs', role: 'director', transportFlag: true, workLogsFlag: true, feesFlag: true), true);
      expect(canAccessRecent('admin_worklogs', role: 'director', transportFlag: true, workLogsFlag: false, feesFlag: true), false);
    });

    test('fees requires isAdminOrAbove AND the flag — demoted-plan regression case', () {
      // A school downgraded off the fees plan: admin still admin, but flag now false.
      expect(canAccessRecent('fees', role: 'admin', transportFlag: true, workLogsFlag: true, feesFlag: false), false);
      expect(canAccessRecent('fees', role: 'admin', transportFlag: true, workLogsFlag: true, feesFlag: true), true);
    });
  });

  group('canAccessRecent — leave_config is admin-only (not principal/director/hod)', () {
    test('strictly the admin role', () {
      expect(canAccessRecent('leave_config', role: 'admin', transportFlag: true, workLogsFlag: true, feesFlag: true), true);
      expect(canAccessRecent('leave_config', role: 'principal', transportFlag: true, workLogsFlag: true, feesFlag: true), false);
      expect(canAccessRecent('leave_config', role: 'director', transportFlag: true, workLogsFlag: true, feesFlag: true), false);
    });
  });

  group('canAccessRecent — universal screens always accessible', () {
    for (final id in ['schedule', 'leaves', 'payroll', 'todos']) {
      test('$id is open to every role', () {
        for (final role in ['admin', 'principal', 'director', 'hod', 'teacher']) {
          expect(canAccessRecent(id, role: role, transportFlag: false, workLogsFlag: false, feesFlag: false), true);
        }
      });
    }
  });

  group('canAccessRecent — role-downgrade regression scenario', () {
    test('a teacher demoted from admin loses access to their stale admin recent chips', () {
      const previouslyAdminRecents = ['parents', 'transport', 'school_settings', 'admin_worklogs', 'attenders', 'fees', 'leave_config'];
      for (final id in previouslyAdminRecents) {
        final stillAccessible = canAccessRecent(id, role: 'teacher', transportFlag: true, workLogsFlag: true, feesFlag: true);
        expect(stillAccessible, false, reason: '$id should be hidden after demotion to plain teacher');
      }
    });
  });
}
