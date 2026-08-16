// Regression guard for a real defect found via a source-level overflow audit
// (Demo-17 pre-demo risk sweep, D5): the "Add Work Log" bottom sheet in
// worklog.dart is a long form (class/section picker, subject dropdown, log
// type, whole-class-or-student search, description, due date, attachments,
// Save button) built as a plain Column with isScrollControlled: true and no
// scroll wrapper -- the same defect class already fixed once in
// admin_teacher_roles.dart's Staff Roles sheet (see admin_teacher_roles_test.dart).
// With the keyboard open on a real phone, Save Work Log could become
// physically unreachable.
//
// This sheet is built inline inside a method closing over many local
// variables and live network calls (loadSubjects, student search), unlike
// TagEditorSheet, which was refactored into a standalone widget specifically
// so it could be pumped in isolation. Extracting the Add Work Log sheet the
// same way, days before a demo, is a real refactor of the single most
// demo-critical screen in the app -- too risky to do just to unlock a widget
// test. This source-guard test gives the same regression protection without
// that risk: it fails loudly if the SingleChildScrollView wrap around this
// specific sheet's content is ever removed.
//
// Pure logic test — reads source from disk, no device required.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Add Work Log sheet content is wrapped in SingleChildScrollView', () {
    final file = File('lib/screens/worklog.dart');
    expect(file.existsSync(), isTrue,
        reason: 'Run this test from the teacher_app package root.');

    final content = file.readAsStringSync();

    final sheetStart = content.indexOf("'Add Work Log'");
    expect(sheetStart, greaterThanOrEqualTo(0),
        reason: "Could not locate the 'Add Work Log' sheet in worklog.dart — "
            'this test\'s anchor text may need updating if the sheet was '
            'renamed, not that the defect is fixed.');

    final saveButtonMarker = content.indexOf("'Save Work Log'", sheetStart);
    expect(saveButtonMarker, greaterThan(sheetStart),
        reason: "Could not locate the 'Save Work Log' button after the "
            'sheet\'s title — this test\'s anchor text may need updating.');

    // The scroll wrapper must appear between the sheet opening (just before
    // its title) and its Save button, i.e. actually wrapping the form's
    // content, not just present somewhere else in the file.
    final wrapperStart = content.lastIndexOf('showModalBottomSheet(', sheetStart);
    expect(wrapperStart, greaterThanOrEqualTo(0));

    final relevantSlice = content.substring(wrapperStart, saveButtonMarker);
    expect(
      relevantSlice.contains('SingleChildScrollView'),
      isTrue,
      reason:
          'The Add Work Log sheet no longer wraps its content in a '
          'SingleChildScrollView. On a real phone with the keyboard open, '
          'this reintroduces the defect where Save Work Log can be pushed '
          'below the visible viewport with nothing to scroll it into view.',
    );
  });
}
