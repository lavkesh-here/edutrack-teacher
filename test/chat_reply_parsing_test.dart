// Pure logic test for ChatReply.fromJson — the shared response shape for
// Ask Vidya and EduTrack Support, added 2026-08-02 alongside the new
// "suggested follow-up questions after every reply" feature.

import 'package:flutter_test/flutter_test.dart';

class _ChatReply {
  final String reply;
  final List<String> suggestedQuestions;
  const _ChatReply({required this.reply, this.suggestedQuestions = const []});

  factory _ChatReply.fromJson(Map<String, dynamic> j) => _ChatReply(
        reply: j['reply'] as String? ?? '',
        suggestedQuestions: (j['suggested_questions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

void main() {
  test('parses reply with suggestions', () {
    final r = _ChatReply.fromJson({
      'reply': 'Attendance is 90% this month.',
      'suggested_questions': ['How many days absent?', 'What about last month?'],
    });
    expect(r.reply, 'Attendance is 90% this month.');
    expect(r.suggestedQuestions, ['How many days absent?', 'What about last month?']);
  });

  test('missing suggested_questions defaults to empty list', () {
    final r = _ChatReply.fromJson({'reply': 'Just an answer.'});
    expect(r.suggestedQuestions, isEmpty);
  });

  test('missing reply defaults to empty string, not a crash', () {
    final r = _ChatReply.fromJson({'suggested_questions': <String>[]});
    expect(r.reply, '');
  });
}
