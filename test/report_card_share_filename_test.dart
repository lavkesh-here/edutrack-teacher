// Pure logic test for the report-card share filename generation added
// alongside the "share report card as PDF" feature in
// student_profile_detail.dart's _FullReportCardTabState._shareReport().

import 'package:flutter_test/flutter_test.dart';

String _reportFilename(String? studentName) {
  final name = studentName ?? 'report';
  return 'report_${name.replaceAll(' ', '_')}.pdf';
}

void main() {
  test('spaces in student name become underscores', () {
    expect(_reportFilename('Anjali Verma'), 'report_Anjali_Verma.pdf');
  });

  test('falls back to a generic name when student_name is missing', () {
    expect(_reportFilename(null), 'report_report.pdf');
  });

  test('single-word name needs no substitution', () {
    expect(_reportFilename('Kabir'), 'report_Kabir.pdf');
  });
}
