import 'dart:math';

/// Short motivational/creative messages shown on pull-to-refresh and on
/// screens like My TODOs, to give small screens with little else to look at
/// a bit of warmth. Kept teacher-specific rather than generic productivity
/// quotes.
class Motivation {
  static const List<String> _messages = [
    "Every lesson you plan today shapes someone's tomorrow.",
    "Small consistent effort beats occasional bursts — one task at a time.",
    "Your students remember how you made them feel more than what you taught.",
    "A cleared to-do list is nice. A student who finally 'got it' is nicer.",
    "Teaching is the one job that creates all other jobs. Well done, today.",
    "You don't have to finish everything today — just start the next thing.",
    "The best teachers are still learning. You're doing great.",
    "One patient explanation can change how a student sees a whole subject.",
    "Progress, not perfection — check off what you can, carry the rest forward.",
    "Somewhere, a student is more confident because of something you did this week.",
    "Great classrooms are built one ordinary Tuesday at a time.",
    "Your effort today is invisible now, but it compounds.",
  ];

  static final Random _rng = Random();

  /// A random message, different from [exclude] where possible (so refreshing
  /// twice in a row doesn't show the exact same line).
  static String random({String? exclude}) {
    if (_messages.length <= 1) return _messages.first;
    String pick;
    do {
      pick = _messages[_rng.nextInt(_messages.length)];
    } while (pick == exclude);
    return pick;
  }
}
