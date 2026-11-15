import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_video/skeleton_video.dart';

const meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> videoRow(
  String id, {
  String status = 'UPLOADED',
  int bytes = 10,
}) => {
  'id': id,
  'purpose': 'attachment',
  'visibility': 'PRIVATE',
  'status': status,
  'bytes': bytes,
  'compat': 'NONE',
  'ladder': 'NONE',
  'progress': null,
  'failCode': null,
  'width': null,
  'height': null,
  'durationMs': null,
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};

/// A file of [length] bytes that live in memory (`0, 1, 2 ...`).
XFile memoryVideo(
  int length, {
  String name = 'walk.mov',
  String mimeType = 'video/quicktime',
}) => XFile.fromData(
  Uint8List.fromList([for (var i = 0; i < length; i++) i]),
  path: '/library/$name',
  mimeType: mimeType,
);

/// A scripted video module: the calls of `VideoApi` and the part `PUT`s.
class FakeVideoServer {
  /// Bytes per part the server asks for.
  int partSize = 4;

  /// What `GET parts` says; null means 404 (the upload is gone).
  List<Map<String, Object?>>? stored;

  final startBodies = <Object?>[];
  final presigned = <List<int>>[];
  final completeBodies = <Object?>[];
  final deleted = <String>[];

  late final FakeAdapter adapter = FakeAdapter((o) async {
    final path = o.path;
    if (path == '/videos' && o.method == 'POST') {
      startBodies.add(o.data);
      final bytes = (o.data as Map)['bytes']! as int;
      return FakeAdapter.json(201, {
        'value': {
          'id': 'v1',
          'uploadId': 'u1',
          'partSize': partSize,
          'partCount': (bytes / partSize).ceil(),
        },
        'meta': meta,
      });
    }
    if (path == '/videos/v1/parts' && o.method == 'POST') {
      final numbers = [
        for (final n in (o.data as Map)['numbers']! as List) n as int,
      ];
      onPresign?.call();
      presigned.add(numbers);
      return FakeAdapter.json(200, {
        'values': [
          for (final n in numbers)
            {
              'number': n,
              'method': 'PUT',
              'url':
                  'https://bucket.example.com/v1/$n?X-Signature=secret&c=${presigned.length}',
              'headers': {'Content-Type': 'video/quicktime'},
            },
        ],
        'meta': meta,
      });
    }
    if (path == '/videos/v1/parts' && o.method == 'GET') {
      final parts = stored;
      if (parts == null) {
        return FakeAdapter.json(404, {
          'code': 'VIDEO.NOT_FOUND',
          'title': 'gone',
          'status': 404,
        });
      }
      return FakeAdapter.json(200, {'values': parts, 'meta': meta});
    }
    if (path == '/videos/v1/complete') {
      completeBodies.add(o.data);
      return FakeAdapter.json(200, {'value': videoRow('v1'), 'meta': meta});
    }
    if (path == '/videos/v1' && o.method == 'GET') {
      return FakeAdapter.json(200, {
        'value': videoRow('v1', status: 'PLAYABLE'),
        'meta': meta,
      });
    }
    if (path == '/videos/v1/playback') {
      return FakeAdapter.json(200, {
        'value': {
          'src': '/api/v1/videos/play/t/o-1/index.m3u8',
          'compat': '/api/v1/videos/play/t/c-1/index.m3u8',
          'hls': null,
          'poster': '/api/v1/videos/play/t/poster.jpg',
          'codec': 'hvc1.1.6.L93.B0',
          'w': 1920,
          'h': 1080,
          'durationMs': 42000,
          'big': false,
          'expiresAt': '2026-01-01T01:00:00Z',
        },
        'meta': meta,
      });
    }
    if (path == '/videos/v1' && o.method == 'DELETE') {
      deleted.add('v1');
      return FakeAdapter.empty(204);
    }
    throw StateError('unexpected ${o.method} $path');
  });

  late final ApiClient client = ApiClient(
    baseUrl: 'https://api.example.com/api/v1',
    adapter: adapter,
    headerProviders: [
      () => {'Authorization': 'Bearer app-token'},
    ],
  );

  late final VideoApi api = VideoApi(client);

  /// The part `PUT`s as the test sees them: number and the bytes sent. A part
  /// that is in [failures] fails that many times before it goes through.
  final puts = <(int, List<int>)>[];

  /// Told of every presign ask before it is counted.
  void Function()? onPresign;

  /// Told of every part `PUT` before it runs.
  void Function(PartTarget target)? onPut;
  final failures = <int, int>{};

  Future<String> put(
    PartTarget target,
    Stream<List<int>> body,
    int length,
    void Function(int sent) onProgress, [
    CancelToken? cancelToken,
  ]) async {
    onPut?.call(target);
    final bytes = [for (final c in await body.toList()) ...c];
    final left = failures[target.number] ?? 0;
    if (left > 0) {
      failures[target.number] = left - 1;
      throw UploadPartError(target.number);
    }
    puts.add((target.number, bytes));
    onProgress(bytes.length);
    return '"etag-${target.number}"';
  }

  final sleeps = <Duration>[];
  Future<void> sleep(Duration d) async => sleeps.add(d);
}

/// The plain `Dio` of a part `PUT` with a scripted storage host.
class FakePartHost {
  int status = 200;
  Map<String, List<String>> responseHeaders = {
    'etag': ['"abc"'],
  };
  late final FakeAdapter adapter = FakeAdapter(
    (o) async => ResponseBody.fromString('', status, headers: responseHeaders),
  );
  late final Dio dio = Dio()..httpClientAdapter = adapter;
}
