import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_video/skeleton_video.dart';

VideoPlayback grant({
  String? compat,
  String? hls,
  bool big = false,
  String? expiresAt = '2026-01-01T01:00:00Z',
}) => VideoPlayback(
  src: 'src',
  compat: compat,
  hls: hls,
  poster: 'poster',
  codec: 'hvc1.1.6.L93.B0',
  width: 1920,
  height: 1080,
  durationMs: 42000,
  big: big,
  expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt),
);

void main() {
  group('playbackUrls', () {
    test('the original tier is the one, and the compat tier the other', () {
      expect(playbackUrls(grant()), ['src']);
      expect(playbackUrls(grant(compat: 'compat')), ['src', 'compat']);
    });

    test('a big original goes second to its compat tier when there is one', () {
      expect(playbackUrls(grant(compat: 'compat', big: true)), [
        'compat',
        'src',
      ]);
    });

    test('a big original with no compat tier yet is still tried', () {
      expect(playbackUrls(grant(big: true)), ['src']);
    });
  });

  group('grantExpired', () {
    final now = DateTime.utc(2026, 1, 1, 0, 59, 40);

    test('is true within 30 seconds of the end, or past it', () {
      expect(grantExpired(grant(), now), isTrue);
      expect(grantExpired(grant(), DateTime.utc(2026, 1, 1, 2)), isTrue);
    });

    test('is false before that, and for a grant that never ends', () {
      expect(grantExpired(grant(), DateTime.utc(2026, 1, 1, 0, 59)), isFalse);
      expect(grantExpired(grant(expiresAt: null), now), isFalse);
    });
  });

  group('afterFailure', () {
    final soon = DateTime.utc(2026, 1, 1, 0, 59, 50);
    final early = DateTime.utc(2026, 1, 1, 0, 10);

    test('asks for a new grant once when the old one ran out', () {
      final g = grant(compat: 'compat');
      expect(
        afterFailure(grant: g, tried: ['src'], now: soon).action,
        FailureAction.refresh,
      );
      // Not again: the second failure goes on to the other tier.
      final next = afterFailure(
        grant: g,
        tried: ['src'],
        now: soon,
        refreshed: true,
      );
      expect((next.action, next.url), (FailureAction.next, 'compat'));
    });

    test('tries the tier not tried yet, then gives up', () {
      final g = grant(compat: 'compat');
      final next = afterFailure(grant: g, tried: ['src'], now: early);
      expect((next.action, next.url), (FailureAction.next, 'compat'));
      expect(
        afterFailure(grant: g, tried: ['src', 'compat'], now: early).action,
        FailureAction.giveUp,
      );
    });
  });
}
