// Regression test for a real defect found via live device testing (not caught
// by any prior automated test): TagEditorSheet's content was a plain Column
// with no scroll wrapper. On a real phone, Nurse + 4 tags + 7 restrict-access
// items pushed the "Save Roles" button past the visible viewport height with
// nothing to scroll -- the button was physically unreachable. Desktop/browser
// checks never caught it because the taller default test/desktop viewport had
// room for everything. This test pins a realistic small-phone height and
// proves the button can actually be scrolled to and is present/enabled.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_teacher/screens/admin_teacher_roles.dart';

const _allTags = [
  ('attender', '🏠 Attender', 'Records visitors'),
  ('sports_teacher', '🏆 Sports Teacher', 'Sports activities'),
  ('hostel_warden', '🏨 Hostel Warden', 'Manages hostel'),
  ('librarian', '📚 Librarian', 'Manages library'),
];

const _restrictableFeatures = [
  ('worklog', '📚 Homework / Classwork', 'Create & view work log entries'),
  ('notify', '🔔 Notify Parents', 'Send messages to parents'),
  ('results', '📊 Tests & Results', 'Post exam scores'),
  ('syllabus', '📖 Syllabus Progress', 'Update chapter completion status'),
  ('ptm', '🤝 PTM', 'Parent-teacher meetings & notes'),
  ('enquiries', '🙋 Enquiries', 'Visitor follow-ups'),
  ('health', '🏥 Health Incidents', 'Log student health events'),
];

Widget _harness({required double height}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: height,
        child: TagEditorSheet(
          teacherId: 'teacher-1',
          teacherName: 'Anjali Verma',
          currentTags: const [],
          allTags: _allTags,
          currentIsNurse: false,
          currentDisabledFeatures: const [],
          restrictableFeatures: _restrictableFeatures,
          isRestrictable: true,
          onSaved: (_, __) {},
          onNurseToggled: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('TagEditorSheet — Save Roles reachability', () {
    testWidgets(
      'on a realistic small-phone height, Save Roles is scrollable into view with no overflow',
      (tester) async {
        // ~740 logical px tall content area -- representative of a compact
        // Android phone's available height once status/nav chrome is
        // subtracted, comparable to the device in the bug report.
        await tester.pumpWidget(_harness(height: 740));
        await tester.pump();

        // The unscrolled build must not overflow -- this alone reproduces
        // the original defect if the SingleChildScrollView wrapper regresses.
        expect(tester.takeException(), isNull);

        final saveButton = find.byKey(const Key('save_roles_button'));
        await tester.scrollUntilVisible(saveButton, 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();

        expect(saveButton, findsOneWidget);
        expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping a restrict-access item toggles its visual state without needing a save round-trip',
      (tester) async {
        await tester.pumpWidget(_harness(height: 740));
        await tester.pump();

        final homeworkTile = find.byKey(const Key('restrict_worklog'));
        await tester.scrollUntilVisible(homeworkTile, 150, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();

        // Not yet restricted -> visible-eye icon
        expect(find.descendant(of: homeworkTile, matching: find.byIcon(Icons.visibility_outlined)), findsOneWidget);

        await tester.tap(homeworkTile);
        await tester.pump();

        // Now restricted -> crossed-eye icon
        expect(find.descendant(of: homeworkTile, matching: find.byIcon(Icons.visibility_off)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'on an even shorter viewport (small/older device), Save Roles is still reachable',
      (tester) async {
        await tester.pumpWidget(_harness(height: 560));
        await tester.pump();
        expect(tester.takeException(), isNull);

        final saveButton = find.byKey(const Key('save_roles_button'));
        await tester.scrollUntilVisible(saveButton, 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();

        expect(saveButton, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
