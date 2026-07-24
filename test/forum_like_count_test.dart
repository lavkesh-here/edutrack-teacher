// Regression test for the forum post-like count bug.
//
// _AnnouncementCard._toggleLike() in lib/screens/feed.dart used to compute
// the post-toggle like count as `wasCount + (nowLiked ? 1 : 0)`, which
// forgot to also subtract the prior optimistic state. On unlike
// (wasLiked=true -> nowLiked=false) this evaluated to `wasCount + 0`,
// silently cancelling the optimistic decrement so the count never went
// down. Fixed formula replicated here for a pure-logic regression test
// (screens can't be imported directly in this project's test setup — see
// session48_test.dart / session43_test.dart for the same convention).

import 'package:flutter_test/flutter_test.dart';

int nextLikeCount(int wasCount, bool wasLiked, bool nowLiked) {
  return wasCount + (nowLiked ? 1 : 0) - (wasLiked ? 1 : 0);
}

void main() {
  group('Forum post like count after server sync', () {
    test('like: not liked -> liked increments by 1', () {
      expect(nextLikeCount(10, false, true), 11);
    });

    test('unlike: liked -> not liked decrements by 1 (the bug case)', () {
      expect(nextLikeCount(11, true, false), 10);
    });

    test('server confirms no-op like->like: count unchanged', () {
      expect(nextLikeCount(11, true, true), 11);
    });

    test('server confirms no-op unlike->unlike (race): count unchanged', () {
      expect(nextLikeCount(10, false, false), 10);
    });

    test('repeated like/unlike toggles never drift', () {
      var count = 5;
      // like
      count = nextLikeCount(count, false, true);
      expect(count, 6);
      // unlike
      count = nextLikeCount(count, true, false);
      expect(count, 5);
      // like again
      count = nextLikeCount(count, false, true);
      expect(count, 6);
      // unlike again
      count = nextLikeCount(count, true, false);
      expect(count, 5);
    });
  });
}
