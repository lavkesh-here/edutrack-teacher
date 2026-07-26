// Regression test for the work log list card missing the chapter it was
// tied to and that chapter's syllabus status — teachers had to open the
// Syllabus screen separately to check whether a logged chapter was
// in_progress or completed. Logic replicated here per this project's test
// convention (see worklog_subject_picker_test.dart).
import 'package:flutter_test/flutter_test.dart';

String chapterChipLabel(String? status) {
  return switch (status) {
    'completed' => 'Done',
    'in_progress' => 'In Progress',
    _ => 'Not Started',
  };
}

void main() {
  group('Work log chapter status chip label', () {
    test('completed status shows Done', () {
      expect(chapterChipLabel('completed'), 'Done');
    });

    test('in_progress status shows In Progress', () {
      expect(chapterChipLabel('in_progress'), 'In Progress');
    });

    test('null status (no syllabus_progress row yet) shows Not Started', () {
      expect(chapterChipLabel(null), 'Not Started');
    });
  });
}
