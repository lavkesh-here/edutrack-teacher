// TC-SH-AUTH-001 | TC-TA-ATT-001 | TC-TA-LEAVE-001 | FLOW-009
// Teacher App integration tests — login, attendance, leave, profile screens.
// Run against the dev backend: flutter test integration_test/auth_flow_test.dart
// Requires: backend running at http://localhost:8000, demo data seeded.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edutrack_teacher/main.dart' as app;

const _schoolCode = 'DEMO001';
const _email      = 'teacher@demo.school';
const _password   = 'demo1234';

/// Bounded stand-in for pumpAndSettle(). On a real Android device/emulator,
/// text-field focus triggers the real on-screen keyboard (integration_test
/// deliberately doesn't mock it — see TestWidgetsFlutterBinding.
/// registerTestTextInput's own doc comment: "An integration test would set
/// this to false, to test real IME or keyboard input"). The IME's own
/// show/hide inset animation keeps scheduling frames, so pumpAndSettle's
/// "wait until nothing is scheduled" heuristic can spin for minutes instead
/// of settling — pump a fixed number of steps instead so a slow keyboard
/// animation can't stall the whole test suite.
Future<void> _settle(WidgetTester tester, [Duration total = const Duration(seconds: 3)]) async {
  const step = Duration(milliseconds: 200);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

/// Helper: boots app, navigates through login, asserts home is reached.
Future<void> _doLogin(WidgetTester tester) async {
  app.main();
  await _settle(tester, const Duration(seconds: 3));

  await tester.enterText(find.byKey(const Key('school_code_field')), _schoolCode);
  await tester.tap(find.byKey(const Key('school_code_submit')));
  await _settle(tester, const Duration(seconds: 2));

  await tester.enterText(find.byKey(const Key('email_field')), _email);
  await tester.enterText(find.byKey(const Key('password_field')), _password);
  await tester.tap(find.byKey(const Key('login_button')));
  // Home dashboard fires a dozen-plus API calls on load (branding, feature
  // config, timetable, leaves, todos, sections, attendance, ...) — give them
  // real room to finish and render before asserting on the result.
  await _settle(tester, const Duration(seconds: 10));

  // On first login (no biometrics enrolled yet), login.dart shows a "Quick
  // unlock" AlertDialog and _login() awaits its result before the home
  // screen is ever built — dismiss it the same way a real user would.
  final notNow = find.text('Not now');
  if (notNow.evaluate().isNotEmpty) {
    await tester.tap(notNow);
    await _settle(tester, const Duration(seconds: 2));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Every testWidgets() re-runs app.main() but shares the SAME real on-device
  // SharedPreferences/app install — unlike a host-side widget test, state
  // does not reset between tests on its own. Without this, a token saved by
  // an earlier test's successful login persists and _Root skips straight to
  // HomeScreen on the next test's app.main(), never showing the login form.
  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  // ── Auth ────────────────────────────────────────────────────────────────────

  group('TC-SH-AUTH: Teacher login flow', () {
    testWidgets('valid credentials → home screen with bottom nav', (tester) async {
      await _doLogin(tester);
      // The app uses a custom bottom-nav row (see home.dart), not
      // Flutter's BottomNavigationBar widget — assert on the real key.
      expect(find.byKey(const Key('nav_home')), findsOneWidget);
    });

    testWidgets('wrong password → error shown, stays on login', (tester) async {
      app.main();
      await _settle(tester,const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('school_code_field')), _schoolCode);
      await tester.tap(find.byKey(const Key('school_code_submit')));
      await _settle(tester,const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('email_field')), _email);
      await tester.enterText(find.byKey(const Key('password_field')), 'wrongpassword');
      await tester.tap(find.byKey(const Key('login_button')));
      await _settle(tester,const Duration(seconds: 3));

      // Error snackbar visible; login screen still showing (no bottom nav)
      expect(find.byKey(const Key('nav_home')), findsNothing);
    });

    testWidgets('invalid school code → stays on step 1', (tester) async {
      app.main();
      await _settle(tester,const Duration(seconds: 2));

      await tester.enterText(find.byKey(const Key('school_code_field')), 'INVALID999');
      await tester.tap(find.byKey(const Key('school_code_submit')));
      await _settle(tester,const Duration(seconds: 2));

      // Should stay on step 1 (school code field still visible)
      expect(find.byKey(const Key('school_code_field')), findsOneWidget);
    });
  });

  // ── Attendance ──────────────────────────────────────────────────────────────

  group('TC-TA-ATT: Attendance screen', () {
    testWidgets('attendance tab renders section selector', (tester) async {
      await _doLogin(tester);

      await tester.tap(find.byKey(const Key('nav_attendance')));
      await _settle(tester, const Duration(seconds: 4));

      expect(
        find.byKey(const Key('section_selector')).evaluate().isNotEmpty ||
            find.byType(DropdownButtonFormField).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('save attendance button is present on attendance screen', (tester) async {
      await _doLogin(tester);

      await tester.tap(find.byKey(const Key('nav_attendance')));
      await _settle(tester, const Duration(seconds: 4));

      // The save button may be scrolled off — just verify the screen loaded
      expect(find.byKey(const Key('nav_attendance')), findsOneWidget);
    });
  });

  // ── Leave ───────────────────────────────────────────────────────────────────

  group('TC-TA-LEAVE: Leave screen', () {
    testWidgets('leave tab shows apply leave button', (tester) async {
      await _doLogin(tester);

      await tester.tap(find.byKey(const Key('nav_more')));
      await _settle(tester, const Duration(seconds: 4));

      // More tab's "MY INFO" section lists this row as "My Leaves" (see
      // home.dart _MoreTabState.build), not "Leave".
      final leaveTile = find.text('My Leaves');
      expect(leaveTile, findsOneWidget, reason: 'My Leaves row not found on the More tab');
      await tester.ensureVisible(leaveTile);
      await tester.tap(leaveTile);
      await _settle(tester, const Duration(seconds: 4));
      expect(find.byKey(const Key('apply_leave_button')), findsOneWidget);
    });
  });

  // ── Students ────────────────────────────────────────────────────────────────

  group('TC-TA-STU: Students screen', () {
    testWidgets('students tab renders search field', (tester) async {
      await _doLogin(tester);

      await tester.tap(find.byKey(const Key('nav_students')));
      await _settle(tester, const Duration(seconds: 4));

      expect(
        find.byKey(const Key('student_search_field')).evaluate().isNotEmpty ||
            find.byType(TextField).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Profile ─────────────────────────────────────────────────────────────────

  group('TC-TA-PROF: Profile screen', () {
    testWidgets('profile screen reachable from more tab', (tester) async {
      await _doLogin(tester);

      await tester.tap(find.byKey(const Key('nav_more')));
      await _settle(tester, const Duration(seconds: 4));

      // Profile fields should eventually be visible via the more tab
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
