import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

import 'support/fakes.dart';

void main() {
  late FakeStorage server;

  setUp(() => server = FakeStorage());

  test('presign, PUT without the app token, then complete', () async {
    final progress = <double>[];
    final result = await server
        .uploader(complete: true)
        .upload(
          MemoryUpload('a.png', 'image/png', Uint8List(2000)),
          onProgress: (p) => progress.add(p.fraction),
        );

    expect(result.key, 'u/1/a.png');
    expect(result.inspection!.image!.status, ImageStatus.ready);
    expect(server.presigns.single.data, {
      'fileName': 'a.png',
      'contentType': 'image/png',
      'sizeBytes': 2000,
    });
    final put = server.puts.single;
    expect(put.method, 'PUT');
    expect(put.uri.host, 'bucket.example.com');
    expect(put.headers['Content-Type'], 'image/png');
    // the app's token must never reach the storage host
    expect(
      put.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(server.completes.single.data, {'key': 'u/1/a.png'});
    expect(progress, isNotEmpty);
  });

  test('complete: false stops after the PUT', () async {
    final result = await server
        .uploader(complete: false)
        .upload(MemoryUpload('a.png', 'image/png', Uint8List(10)));

    expect(result.inspection, isNull);
    expect(server.completes, isEmpty);
  });

  test('a file that breaks the rules is not sent at all', () async {
    final uploader = server.uploader(
      rules: const StorageFileRules(
        maxSizeBytes: 5,
        allowedContentTypes: ['image/*'],
      ),
    );

    await expectLater(
      uploader.upload(MemoryUpload('a.pdf', 'application/pdf', Uint8List(10))),
      throwsA(
        isA<StorageValidationError>().having(
          (e) => e.issues.map((i) => i.code).toList(),
          'codes',
          ['SIZE_TOO_LARGE', 'UNSUPPORTED_CONTENT_TYPE'],
        ),
      ),
    );
    expect(server.presigns, isEmpty);
    expect(server.puts, isEmpty);
  });

  test('the server refusing the bytes is an UploadRejectedError', () async {
    server.completeResponse = FakeAdapter.json(400, {
      'code': ErrorCodes.storageFileRejected,
      'title': 'Rejected',
      'status': 400,
      'data': {
        'errors': [
          {'code': 'CONTENT_MISMATCH', 'message': 'not a png'},
        ],
      },
    });

    await expectLater(
      server.uploader().upload(
        MemoryUpload('a.png', 'image/png', Uint8List(4)),
      ),
      throwsA(
        isA<UploadRejectedError>().having(
          (e) => e.issues.single.code,
          'code',
          'CONTENT_MISMATCH',
        ),
      ),
    );
  });

  test('the server refusing at presign carries its reasons too', () async {
    server.presignResponse = FakeAdapter.json(400, {
      'code': ErrorCodes.storageFileRejected,
      'title': 'Rejected',
      'status': 400,
      'data': {
        'errors': [
          {'code': 'SIZE_TOO_LARGE', 'message': 'too big'},
        ],
      },
    });

    await expectLater(
      server.uploader().upload(
        MemoryUpload('a.png', 'image/png', Uint8List(4)),
      ),
      throwsA(
        isA<UploadRejectedError>().having(
          (e) => e.issues.single.code,
          'code',
          'SIZE_TOO_LARGE',
        ),
      ),
    );
    expect(server.puts, isEmpty);
  });

  test('a failing PUT is an UploadHttpError and never names the URL', () async {
    server.putStatus = 403;

    await expectLater(
      server.uploader().upload(
        MemoryUpload('a.png', 'image/png', Uint8List(4)),
      ),
      throwsA(
        isA<UploadHttpError>()
            .having((e) => e.status, 'status', 403)
            .having((e) => e.toString(), 'text', isNot(contains('bucket'))),
      ),
    );
    expect(server.completes, isEmpty);
  });

  test('cancelling stops the upload with UploadCancelledError', () async {
    final token = CancelToken()..cancel();

    await expectLater(
      server.uploader().upload(
        MemoryUpload('a.png', 'image/png', Uint8List(4)),
        cancelToken: token,
      ),
      throwsA(isA<UploadCancelledError>()),
    );
    expect(server.puts, isEmpty);
  });

  test('the PUT body is the file bytes', () async {
    final bytes = Uint8List.fromList(utf8.encode('hello photo'));
    await server.uploader().upload(MemoryUpload('a.png', 'image/png', bytes));

    expect(server.putBodies.single, bytes);
  });
}
