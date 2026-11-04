import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:test/test.dart';

import 'support/fake_adapter.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

ApiClient _client(
  FakeAdapter adapter, {
  List<HeaderProvider> headerProviders = const [],
  void Function(ApiRequestError error)? onError,
}) => ApiClient(
  baseUrl: 'http://localhost:8080/api/v1',
  adapter: adapter,
  headerProviders: headerProviders,
  onError: onError,
);

Map<String, Object?> _item(Object? json) => json as Map<String, Object?>;

void main() {
  group('envelope', () {
    test('value() returns the object under "value"', () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(200, {
          'value': {'message': 'hi'},
          'meta': _meta,
        }),
      );

      final result = await _client(adapter)
          .value('/hello', decode: (j) => j['message']);

      expect(result, 'hi');
      expect(
        adapter.requests.single.uri.toString(),
        'http://localhost:8080/api/v1/hello',
      );
    });

    test('list() returns the items under "values"', () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(200, {
          'values': [
            {'id': 1},
            {'id': 2},
          ],
          'meta': _meta,
        }),
      );

      final result = await _client(adapter)
          .list('/things', decode: (j) => j['id']);

      expect(result, [1, 2]);
    });

    test('page() returns the items and the pagination block', () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(200, {
          'values': [
            {'id': 7},
          ],
          'pagination': {
            'page': 0,
            'size': 20,
            'totalElements': 41,
            'totalPages': 3,
            'hasNext': true,
            'hasPrevious': false,
          },
          'meta': _meta,
        }),
      );

      final result = await _client(adapter)
          .page('/things', decode: (j) => j['id']);

      expect(result.items, [7]);
      expect(result.pagination.totalElements, 41);
      expect(result.pagination.hasNext, isTrue);
      expect(result.pagination.hasPrevious, isFalse);
    });

    test('noContent() accepts a 204 without a body', () async {
      final adapter = FakeAdapter((_) => FakeAdapter.empty(204));

      await _client(adapter).noContent('/auth/logout', method: 'POST');

      expect(adapter.requests.single.method, 'POST');
    });

    test(
      'a 200 without the "value" key is a CLIENT.HTTP_ERROR, not a null',
      () async {
        final adapter = FakeAdapter(
          (_) => FakeAdapter.json(200, {'meta': _meta}),
        );

        await expectLater(
          _client(adapter).value('/hello', decode: _item),
          throwsA(
            isA<ApiRequestError>().having(
              (e) => e.code,
              'code',
              ClientErrorCodes.httpError,
            ),
          ),
        );
      },
    );
  });

  group('errors', () {
    test('an ApiError body becomes ApiRequestError with code, message, trace and field errors', () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(400, {
          'code': 'COMMON.VALIDATION_FAILED',
          'title': 'Validation failed',
          'status': 400,
          'detail': 'email format invalid',
          'traceId': 'abc123',
          'timestamp': '2026-01-01T00:00:00Z',
          'errors': [
            {'field': 'email', 'code': 'Pattern', 'message': 'bad'},
          ],
        }),
      );

      final error = await _client(adapter)
          .value('/x', decode: _item)
          .then<ApiRequestError>(
            (_) => fail('should throw'),
            onError: (Object e) => e as ApiRequestError,
          );

      expect(error.code, ErrorCodes.commonValidationFailed);
      expect(error.status, 400);
      expect(error.message, 'email format invalid');
      expect(error.traceId, 'abc123');
      expect(error.fieldErrors.single.field, 'email');
      expect(error.fieldErrors.single.code, 'Pattern');
    });

    test('a non-ApiError body (proxy HTML) is CLIENT.HTTP_ERROR with the real status', () async {
      final adapter = FakeAdapter(
        (_) => ResponseBody.fromString(
          '<html>Bad Gateway</html>',
          502,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );

      final error = await _client(adapter)
          .value('/x', decode: _item)
          .then<ApiRequestError>(
            (_) => fail('should throw'),
            onError: (Object e) => e as ApiRequestError,
          );

      expect(error.code, ClientErrorCodes.httpError);
      expect(error.status, 502);
    });

    test(
      'a connection failure is CLIENT.NETWORK_ERROR with status 0',
      () async {
        final adapter = FakeAdapter(
          (options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'down',
          ),
        );

        final error = await _client(adapter)
            .value('/x', decode: _item)
            .then<ApiRequestError>(
              (_) => fail('should throw'),
              onError: (Object e) => e as ApiRequestError,
            );

        expect(error.code, ClientErrorCodes.networkError);
        expect(error.status, 0);
      },
    );

    test('onError is called once with the error that is thrown', () async {
      final seen = <ApiRequestError>[];
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(401, {
          'code': 'COMMON.UNAUTHORIZED',
          'title': 'Unauthorized',
          'status': 401,
          'timestamp': '2026-01-01T00:00:00Z',
        }),
      );

      await _client(adapter, onError: seen.add)
          .value('/x', decode: _item)
          .then<void>((_) => fail('should throw'), onError: (Object _) {});

      expect(seen, hasLength(1));
      expect(seen.single.code, ErrorCodes.commonUnauthorized);
    });
  });

  group('header providers', () {
    test('are merged into every request; an explicit header wins', () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(200, {
          'value': <String, Object?>{},
          'meta': _meta,
        }),
      );
      final client = _client(
        adapter,
        headerProviders: [
          () => {'X-One': '1', 'X-Both': 'provider'},
          () async => {'X-Two': '2'},
        ],
      );

      await client.value('/x', decode: _item, headers: {'X-Both': 'request'});

      final headers = adapter.requests.single.headers;
      expect(headers['X-One'], '1');
      expect(headers['X-Two'], '2');
      expect(headers['X-Both'], 'request');
    });

    test('skipAuth leaves them out', () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(200, {
          'value': <String, Object?>{},
          'meta': _meta,
        }),
      );
      final client = _client(
        adapter,
        headerProviders: [
          () => {'Authorization': 'Bearer t'},
        ],
      );

      await client.value(
        '/auth/login',
        decode: _item,
        method: 'POST',
        skipAuth: true,
      );

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });
}
