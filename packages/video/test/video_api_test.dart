import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_video/skeleton_video.dart';

import 'support/fakes.dart';

void main() {
  late FakeVideoServer server;

  setUp(() => server = FakeVideoServer());

  test('start reads the id, the upload and the part size', () async {
    final started = await server.api.start(
      bytes: 10,
      contentType: 'video/mp4',
      purpose: 'attachment',
    );
    expect(
      (started.id, started.uploadId, started.partSize, started.partCount),
      ('v1', 'u1', 4, 3),
    );
  });

  test('part addresses come as a list, and never show their address', () async {
    final targets = await server.api.presignParts('v1', [1, 2]);
    expect(targets.map((t) => t.number), [1, 2]);
    expect(targets.first.method, 'PUT');
    expect(targets.first.headers['Content-Type'], 'video/quicktime');
    expect(targets.first.toString(), isNot(contains('secret')));
  });

  test('stored parts say their number, etag and size', () async {
    server.stored = [
      {'n': 1, 'etag': '"a"', 'bytes': 4},
    ];
    final parts = await server.api.listParts('v1');
    expect(
      (parts.single.n, parts.single.etag, parts.single.bytes),
      (1, '"a"', 4),
    );
  });

  test('a video row reads its status, progress and failure', () async {
    final item = await server.api.get('v1');
    expect(item.status, VideoStatus.playable);
    expect(item.durationMs, isNull);
    expect(VideoStatus.parse('REMUXING'), VideoStatus.remuxing);
    expect(VideoStatus.parse('something new'), VideoStatus.failed);
  });

  test('a playback grant reads its addresses and its end', () async {
    final grant = await server.api.playback('v1');
    expect(grant.src, endsWith('o-1/index.m3u8'));
    expect(grant.compat, endsWith('c-1/index.m3u8'));
    expect(grant.hls, isNull);
    expect(grant.big, isFalse);
    expect((grant.width, grant.height), (1920, 1080));
    expect(grant.durationMs, 42000);
    expect(grant.expiresAt, DateTime.utc(2026, 1, 1, 1));
  });

  test('remove is one DELETE', () async {
    await server.api.remove('v1');
    expect(server.deleted, ['v1']);
  });
}
