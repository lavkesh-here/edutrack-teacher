// Regression test for a real defect found via the Demo-17 pre-demo overflow
// audit (same class already fixed twice: admin_teacher_roles.dart's Staff
// Roles sheet, worklog.dart's Add Work Log sheet): QualificationsFormSheet
// (shared by both "Add Education" and "Add Work Experience" in
// qualifications.dart) was a plain Column with isScrollControlled: true and
// no scroll wrapper. Both callers have enough fields -- including a
// From/To-year row and a checkbox -- to plausibly push Save below the
// visible viewport once the keyboard is open on a real phone.
//
// Unlike worklog.dart's sheet, this one closes over no screen state or
// network calls -- a clean StatelessWidget with a simple constructor -- so
// it was made public (renamed from _BottomSheet) and is pumped directly
// here, the same way TagEditorSheet is tested.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_teacher/screens/qualifications.dart';

Widget _harness({required double height, required List<Widget> children}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: height,
        child: QualificationsFormSheet(
          title: 'Add Work Experience',
          saving: false,
          onSave: () {},
          children: children,
        ),
      ),
    ),
  );
}

List<Widget> _experienceLikeFields() => [
      const TextField(decoration: InputDecoration(hintText: 'Institution')),
      const SizedBox(height: 14),
      const TextField(decoration: InputDecoration(hintText: 'Role')),
      const SizedBox(height: 14),
      Row(
        children: const [
          Expanded(child: TextField(decoration: InputDecoration(hintText: 'From Year'))),
          SizedBox(width: 12),
          Expanded(child: TextField(decoration: InputDecoration(hintText: 'To Year'))),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: const [
          Icon(Icons.check_box_outline_blank),
          Text('I currently work here'),
        ],
      ),
    ];

void main() {
  group('QualificationsFormSheet — Save reachability', () {
    testWidgets(
      'on a realistic small-phone height, Save is scrollable into view with no overflow',
      (tester) async {
        // Same 740px benchmark used by the Staff Roles regression test --
        // representative of a compact Android phone's available height once
        // status/nav chrome is subtracted.
        await tester.pumpWidget(_harness(height: 740, children: _experienceLikeFields()));
        await tester.pump();

        expect(tester.takeException(), isNull);

        final saveButton = find.byKey(const Key('qualifications_sheet_save_button'));
        await tester.scrollUntilVisible(saveButton, 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();

        expect(saveButton, findsOneWidget);
        expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'on a shorter viewport with the keyboard-open-equivalent height, Save is still reachable',
      (tester) async {
        await tester.pumpWidget(_harness(height: 480, children: _experienceLikeFields()));
        await tester.pump();
        expect(tester.takeException(), isNull);

        final saveButton = find.byKey(const Key('qualifications_sheet_save_button'));
        await tester.scrollUntilVisible(saveButton, 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();

        expect(saveButton, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
