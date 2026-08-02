// Pure logic test for the natural-sort comparator added alongside the
// student-list sorting feature in my_students.dart's _MyStudentsScreenState.

import 'package:flutter_test/flutter_test.dart';

int naturalCompare(String a, String b) {
  final aParts = RegExp(r'(\d+|\D+)').allMatches(a).map((m) => m.group(0)!).toList();
  final bParts = RegExp(r'(\d+|\D+)').allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < aParts.length && i < bParts.length; i++) {
    final ap = aParts[i], bp = bParts[i];
    final aNum = int.tryParse(ap), bNum = int.tryParse(bp);
    final cmp = (aNum != null && bNum != null)
        ? aNum.compareTo(bNum)
        : ap.toLowerCase().compareTo(bp.toLowerCase());
    if (cmp != 0) return cmp;
  }
  return aParts.length.compareTo(bParts.length);
}

void main() {
  test('roll numbers sort numerically, not lexicographically', () {
    final rolls = ['10', '2', '1', '20', '3'];
    rolls.sort(naturalCompare);
    expect(rolls, ['1', '2', '3', '10', '20']);
  });

  test('admission numbers with a shared alpha prefix sort numerically on the digit run', () {
    final admissions = ['DM5A010', 'DM5A002', 'DM5A001', 'DM5A020'];
    admissions.sort(naturalCompare);
    expect(admissions, ['DM5A001', 'DM5A002', 'DM5A010', 'DM5A020']);
  });

  test('plain alphabetic strings still sort like a normal string compare', () {
    final names = ['Vihaan', 'Aarav', 'Myra', 'Ishita'];
    names.sort(naturalCompare);
    expect(names, ['Aarav', 'Ishita', 'Myra', 'Vihaan']);
  });

  test('empty roll number does not throw and sorts before non-empty ones', () {
    final rolls = ['5', '', '1'];
    rolls.sort(naturalCompare);
    expect(rolls, ['', '1', '5']);
  });
}
