// Regression coverage for the SOS history/resolution feature: previously
// only the last 5 SOS events were ever visible (embedded in the director
// dashboard response), with no dedicated listing screen and no way to mark
// one resolved from the app. Logic replicated here per this project's test
// convention (see worklog_subject_picker_test.dart) — the tab-to-resolved
// query param mapping is the only non-trivial logic in the new screen.
import 'package:flutter_test/flutter_test.dart';

enum SOSTab { unresolved, resolved, all }

bool? sosTabToResolvedParam(SOSTab tab) {
  return switch (tab) {
    SOSTab.unresolved => false,
    SOSTab.resolved => true,
    SOSTab.all => null,
  };
}

void main() {
  group('SOS tab -> resolved query param', () {
    test('unresolved tab requests resolved=false', () {
      expect(sosTabToResolvedParam(SOSTab.unresolved), isFalse);
    });

    test('resolved tab requests resolved=true', () {
      expect(sosTabToResolvedParam(SOSTab.resolved), isTrue);
    });

    test('all tab requests no filter (null)', () {
      expect(sosTabToResolvedParam(SOSTab.all), isNull);
    });
  });
}
