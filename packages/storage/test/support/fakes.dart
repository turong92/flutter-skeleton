import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

const meta = {'timestamp': '2026-01-01T00:00:00Z'};

/// An in-memory file.
class MemoryUpload implements UploadFile {
  MemoryUpload(this.name, this.contentType, this.bytes);

  @override
  final String name;
  @override
  final String contentType;
  final Uint8List bytes;

  @override
  Future<int> length() async => bytes.length;

  @override
  Stream<List<int>> openRead() => Stream.value(bytes);

  @override
  Future<Uint8List> readAsBytes() async => bytes;
}

/// A scripted backend plus a scripted storage host. The app's `ApiClient` adds
/// a bearer token to its calls, like the real one, so a test can tell whether
/// the token reached the storage host.
class FakeStorage {
  ResponseBody? completeResponse;
  ResponseBody? presignResponse;
  int putStatus = 200;
  final List<List<int>> putBodies = [];

  late final FakeAdapter apiAdapter = FakeAdapter((o) async {
    if (o.path == '/storage/presign') {
      return presignResponse ??
          FakeAdapter.json(200, {
            'value': {
              'key': 'u/1/${(o.data as Map)['fileName']}',
              'method': 'PUT',
              'url': 'https://bucket.example.com/u/1/file?X-Signature=secret',
              'headers': {'Content-Type': (o.data as Map)['contentType']},
              'expiresAt': '2026-01-01T00:10:00Z',
            },
            'meta': meta,
          });
    }
    if (o.path == '/storage/complete') {
      return completeResponse ??
          FakeAdapter.json(200, {
            'value': {
              'key': (o.data as Map)['key'],
              'contentType': 'image/png',
              'sizeBytes': 2000,
              'image': {'status': 'READY', 'width': 800, 'height': 600},
            },
            'meta': meta,
          });
    }
    throw StateError('unexpected ${o.method} ${o.path}');
  });

  late final FakeAdapter putAdapter = FakeAdapter((o) async {
    putBodies.add([
      for (final c in await (o.data as Stream).toList()) ...(c as List<int>),
    ]);
    return FakeAdapter.empty(putStatus);
  });

  late final ApiClient client = ApiClient(
    baseUrl: 'https://api.example.com/api/v1',
    adapter: apiAdapter,
    headerProviders: [
      () => {'Authorization': 'Bearer app-token'},
    ],
  );

  List<RequestOptions> get presigns => [
    for (final r in apiAdapter.requests)
      if (r.path == '/storage/presign') r,
  ];
  List<RequestOptions> get completes => [
    for (final r in apiAdapter.requests)
      if (r.path == '/storage/complete') r,
  ];
  List<RequestOptions> get puts => putAdapter.requests;

  Uploader uploader({
    StorageFileRules rules = const StorageFileRules(),
    bool complete = true,
  }) {
    final putClient = Dio()..httpClientAdapter = putAdapter;
    return Uploader(
      api: StorageApi(client),
      putClient: putClient,
      rules: rules,
      complete: complete,
    );
  }
}
