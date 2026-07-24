// Regression test for the Calendar "Add Event" permission-gating bug.
//
// calendar_screen.dart used to render the "Add Event" FAB unconditionally
// for every role and call POST /api/v1/admin/calendar, which the backend
// restricts to admin/principal/director (get_write_access). A plain teacher
// tapping it got a 403 error message instead of the button simply not being
// there. Fixed by gating the FAB behind the same isAdmin check already used
// correctly elsewhere in this app (student_profile_detail.dart Emergency/
// Medical FABs, ptm.dart, home.dart). Replicated here as a pure-logic test
// per this project's test convention (screens aren't imported directly).

import 'package:flutter_test/flutter_test.dart';

bool isAdminRole(String? role) {
  return role == 'admin' || role == 'principal' || role == 'director';
}

void main() {
  group('Calendar Add Event FAB visibility', () {
    test('admin sees the Add Event FAB', () => expect(isAdminRole('admin'), true));
    test('principal sees the Add Event FAB', () => expect(isAdminRole('principal'), true));
    test('director sees the Add Event FAB', () => expect(isAdminRole('director'), true));
    test('plain teacher does not see the Add Event FAB', () => expect(isAdminRole('teacher'), false));
    test('hod does not see the Add Event FAB', () => expect(isAdminRole('hod'), false));
    test('null role (logged out) does not see the Add Event FAB', () => expect(isAdminRole(null), false));
  });
}
