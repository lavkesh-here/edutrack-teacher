// Regression test for a real silent-failure bug: push token registration
// ran once at cold start in _Root.initState(), before login. That first
// registerPushToken() call 401s on a fresh install (no session yet) and was
// silently swallowed (`catch (_) {}`), with no retry — so a fresh install's
// FCM token never reached the backend's push_tokens table, and the teacher
// could never receive a push for anything (leave review, homework
// acknowledgment, etc.) until Firebase happened to rotate the token on its
// own. Same bug found and fixed in parent_app's main.dart.
//
// Fixed by stashing the token from _setupFcm() and retrying registration
// from _handleAuthChange() on the false->true login transition. Logic
// replicated here per this project's test convention (see
// worklog_subject_picker_test.dart) since _RootState is private and Firebase
// plugins aren't available under `flutter test`.
import 'package:flutter_test/flutter_test.dart';

bool shouldRetryFcmRegistration({
  required bool isLoggedIn,
  required bool wasLoggedIn,
  required bool hasToken,
}) {
  final justLoggedIn = isLoggedIn && !wasLoggedIn;
  return justLoggedIn && hasToken;
}

void main() {
  group('FCM registration retry on login', () {
    test('fresh login with a token in hand triggers a retry', () {
      expect(
        shouldRetryFcmRegistration(isLoggedIn: true, wasLoggedIn: false, hasToken: true),
        isTrue,
      );
    });

    test('no retry if the token was never obtained (Firebase unavailable)', () {
      expect(
        shouldRetryFcmRegistration(isLoggedIn: true, wasLoggedIn: false, hasToken: false),
        isFalse,
      );
    });

    test('no retry on logout', () {
      expect(
        shouldRetryFcmRegistration(isLoggedIn: false, wasLoggedIn: true, hasToken: true),
        isFalse,
      );
    });

    test('no retry for an already-logged-in session (app resume, not a fresh login)', () {
      expect(
        shouldRetryFcmRegistration(isLoggedIn: true, wasLoggedIn: true, hasToken: true),
        isFalse,
      );
    });

    test('no retry while logged out throughout', () {
      expect(
        shouldRetryFcmRegistration(isLoggedIn: false, wasLoggedIn: false, hasToken: true),
        isFalse,
      );
    });
  });
}
