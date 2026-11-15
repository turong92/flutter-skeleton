import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skeleton_video/skeleton_video.dart';

import 'support/fakes.dart';

void main() {
  late FakeVideoServer server;

  setUp(() => server = FakeVideoServer());

  Future<VideoItem> upload(
    XFile file, {
    VideoUploadSession? resume,
    Future<void> Function(VideoUploadSession)? onStarted,
    List<int>? progress,
    CancelToken? cancelToken,
    DateTime Function()? now,
    PartPut? put,
  }) => uploadVideo(
    server.api,
    file,
    purpose: 'attachment',
    resume: resume,
    onStarted: onStarted,
    onProgress: progress?.add,
    put: put ?? server.put,
    sleep: server.sleep,
    cancelToken: cancelToken,
    now: now,
  );

  test('starts with the size, the type, the purpose and PRIVATE', () async {
    await upload(memoryVideo(10));
    expect(server.startBodies.single, {
      'bytes': 10,
      'contentType': 'video/quicktime',
      'purpose': 'attachment',
      'visibility': 'PRIVATE',
    });
  });

  test(
    'sends each part with its own bytes and completes with the etags',
    () async {
      final progress = <int>[];
      await upload(memoryVideo(10), progress: progress);
      expect({for (final n in server.presigned) ...n}, {1, 2, 3});
      final sent = {for (final (n, bytes) in server.puts) n: bytes};
      expect(sent[1], [0, 1, 2, 3]);
      expect(sent[2], [4, 5, 6, 7]);
      expect(sent[3], [8, 9]);
      expect(server.completeBodies.single, {
        'parts': [
          {'n': 1, 'etag': '"etag-1"'},
          {'n': 2, 'etag': '"etag-2"'},
          {'n': 3, 'etag': '"etag-3"'},
        ],
      });
      // The bytes sent so far only grow and end at the whole file.
      expect(progress.last, 10);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
    },
  );

  test(
    'a part that fails is sent again with a fresh address, with waits',
    () async {
      server.failures[2] = 2;
      await upload(memoryVideo(10));
      // The first ask is for all three; each retry asks again for that part.
      expect(server.presigned, [
        [1, 2, 3],
        [2],
        [2],
      ]);
      expect(server.sleeps, [
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1000),
      ]);
      expect(server.completeBodies, hasLength(1));
    },
  );

  test(
    'a part that fails four times ends the upload without completing',
    () async {
      server.failures[1] = 4;
      await expectLater(
        upload(memoryVideo(10)),
        throwsA(isA<UploadPartError>().having((e) => e.part, 'part', 1)),
      );
      expect(server.completeBodies, isEmpty);
    },
  );

  test('a resumed upload sends only the parts the storage lacks', () async {
    server.stored = [
      {'n': 1, 'etag': '"old-1"', 'bytes': 4},
      // A part of the wrong size is not trusted.
      {'n': 2, 'etag': '"old-2"', 'bytes': 3},
    ];
    await upload(
      memoryVideo(10),
      resume: const VideoUploadSession(
        id: 'v1',
        uploadId: 'u1',
        partSize: 4,
        bytes: 10,
      ),
    );
    expect(server.startBodies, isEmpty);
    expect({for (final n in server.presigned) ...n}, {2, 3});
    expect((server.completeBodies.single! as Map)['parts'], [
      {'n': 1, 'etag': '"old-1"'},
      {'n': 2, 'etag': '"etag-2"'},
      {'n': 3, 'etag': '"etag-3"'},
    ]);
  });

  test('a resumed upload the server forgot starts again', () async {
    server.stored = null;
    final started = <VideoUploadSession>[];
    await upload(
      memoryVideo(10),
      resume: const VideoUploadSession(
        id: 'v1',
        uploadId: 'old',
        partSize: 4,
        bytes: 10,
      ),
      onStarted: (s) async => started.add(s),
    );
    expect(server.startBodies, hasLength(1));
    expect(started.single.uploadId, 'u1');
    expect(server.puts, hasLength(3));
  });

  test(
    'onStarted is told before any part and a refusal there stops it',
    () async {
      final calls = <String>[];
      await expectLater(
        upload(
          memoryVideo(10),
          onStarted: (s) async {
            calls.add(s.id);
            throw StateError('attach refused');
          },
        ),
        throwsStateError,
      );
      expect(calls, ['v1']);
      expect(server.presigned, isEmpty);
      expect(server.puts, isEmpty);
    },
  );

  test('a cancelled token stops before anything is opened', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      upload(memoryVideo(10), cancelToken: token),
      throwsA(isA<UploadCancelled>()),
    );
    expect(server.startBodies, isEmpty);
    expect(server.puts, isEmpty);
  });

  test(
    'cancelling in the middle sends no more parts and does not complete',
    () async {
      final token = CancelToken();
      server.onPut = (_) => token.cancel();
      await expectLater(
        upload(memoryVideo(48), cancelToken: token),
        throwsA(isA<UploadCancelled>()),
      );
      // The three running at once may finish; the rest are never taken.
      expect(server.puts.length, lessThan(12));
      expect(server.completeBodies, isEmpty);
    },
  );

  test(
    'a resumed session of another size is refused before anything goes',
    () async {
      final started = <VideoUploadSession>[];
      await expectLater(
        upload(
          memoryVideo(11),
          resume: const VideoUploadSession(
            id: 'v1',
            uploadId: 'u1',
            partSize: 4,
            bytes: 10,
          ),
          onStarted: (s) async => started.add(s),
        ),
        throwsA(isA<ResumeFileMismatchError>()),
      );
      expect(started, isEmpty);
      expect(server.startBodies, isEmpty);
      expect(server.presigned, isEmpty);
    },
  );

  test('a big file is signed a few parts at a time, not all at once', () async {
    await upload(memoryVideo(48));
    expect(server.presigned.first.length, lessThan(12));
    expect(
      {for (final n in server.presigned) ...n},
      {for (var n = 1; n <= 12; n++) n},
    );
    expect(server.puts, hasLength(12));
  });

  test(
    'an address signed ten minutes ago is signed again before its PUT',
    () async {
      final base = DateTime.utc(2026, 1, 1);
      var skew = Duration.zero;
      DateTime now() => base.add(skew);
      final signedAt = <int, DateTime>{};
      server.onPresign = () => signedAt[server.presigned.length + 1] = now();
      server.onPut = (target) {
        // The first three go at once, before any part has finished.
        if (target.number <= 3) return;
        final c = int.parse(Uri.parse(target.url).queryParameters['c']!);
        expect(
          now().difference(signedAt[c]!),
          lessThan(const Duration(minutes: 10)),
          reason: 'part ${target.number} went with an old address',
        );
      };
      await upload(
        memoryVideo(48),
        now: now,
        put: (t, b, l, p, [c]) async {
          final etag = await server.put(t, b, l, p, c);
          skew = const Duration(minutes: 11); // a part took that long
          return etag;
        },
      );
      expect(server.puts, hasLength(12));
    },
  );

  test('a cancelled part PUT is UploadCancelled, not a failed part', () async {
    final host = FakePartHost();
    final token = CancelToken()..cancel();
    await expectLater(
      dioPartPut(host.dio)(
        const PartTarget(
          number: 1,
          method: 'PUT',
          url: 'https://b.example.com/x?sig=secret',
          headers: {},
        ),
        Stream.value([1]),
        1,
        (_) {},
        token,
      ),
      throwsA(isA<UploadCancelled>()),
    );
  });

  test(
    'only mp4 and mov are sent, by type or by the ending without one',
    () async {
      expect(videoContentTypeOf(memoryVideo(1)), 'video/quicktime');
      expect(
        videoContentTypeOf(
          memoryVideo(1, name: 'a.mp4', mimeType: 'video/mp4'),
        ),
        'video/mp4',
      );
      expect(
        videoContentTypeOf(
          XFile.fromData(Uint8List(1), path: '/library/a.MOV'),
        ),
        'video/quicktime',
      );
      expect(
        videoContentTypeOf(
          XFile.fromData(Uint8List(1), path: '/library/a.mp4'),
        ),
        'video/mp4',
      );
      expect(
        videoContentTypeOf(
          memoryVideo(1, name: 'a.webm', mimeType: 'video/webm'),
        ),
        isNull,
      );
      await expectLater(
        upload(memoryVideo(1, name: 'a.webm', mimeType: 'video/webm')),
        throwsA(isA<UnsupportedVideoFileError>()),
      );
      expect(server.startBodies, isEmpty);
    },
  );

  test(
    'a part goes to the storage with no app token and gives its etag',
    () async {
      final host = FakePartHost();
      final etag = await dioPartPut(host.dio)(
        const PartTarget(
          number: 1,
          method: 'PUT',
          url: 'https://bucket.example.com/v1/1?X-Signature=secret',
          headers: {'Content-Type': 'video/quicktime'},
        ),
        Stream.value([1, 2, 3]),
        3,
        (_) {},
      );
      expect(etag, '"abc"');
      final request = host.adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.headers['Content-Length'], '3');
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    },
  );

  test(
    'a storage refusal or a missing etag is a failed part, without the address',
    () async {
      final host = FakePartHost()..status = 403;
      await expectLater(
        dioPartPut(host.dio)(
          const PartTarget(
            number: 2,
            method: 'PUT',
            url: 'https://b.example.com/x?sig=secret',
            headers: {},
          ),
          Stream.value([1]),
          1,
          (_) {},
        ),
        throwsA(
          isA<UploadPartError>()
              .having((e) => e.part, 'part', 2)
              .having((e) => e.toString(), 'text', isNot(contains('secret'))),
        ),
      );
      final bare = FakePartHost()..responseHeaders = {};
      await expectLater(
        dioPartPut(bare.dio)(
          const PartTarget(
            number: 1,
            method: 'PUT',
            url: 'https://b.example.com/x',
            headers: {},
          ),
          Stream.value([1]),
          1,
          (_) {},
        ),
        throwsA(isA<UploadPartError>()),
      );
    },
  );

  test('a DioException is not leaked either', () async {
    final dio = Dio()..httpClientAdapter = _Failing();
    await expectLater(
      dioPartPut(dio)(
        const PartTarget(
          number: 1,
          method: 'PUT',
          url: 'https://b.example.com/x?sig=secret',
          headers: {},
        ),
        Stream.value([1]),
        1,
        (_) {},
      ),
      throwsA(isA<UploadPartError>()),
    );
  });
}

class _Failing implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException(requestOptions: options, message: 'offline');

  @override
  void close({bool force = false}) {}
}
