import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:test/test.dart';

ApiClient _client(FakeAdapter adapter) =>
    ApiClient(baseUrl: 'http://localhost:8080/api/v1', adapter: adapter);

Object? _echo(Map<String, Object?> json) => json['message'];

FakeAdapter _ok() => FakeAdapter(
  (_) => FakeAdapter.json(200, {
    'value': {'message': 'hi'},
    'meta': {'timestamp': '2026-01-01T00:00:00Z'},
  }),
);

void main() {
  group('trace id', () {
    test('every request carries a W3C traceparent and X-Trace-Id', () async {
      final adapter = _ok();
      await _client(adapter).value('/hello', decode: _echo);

      final headers = adapter.requests.single.headers;
      expect(
        headers['traceparent'],
        matches(RegExp(r'^00-[0-9a-f]{32}-[0-9a-f]{16}-01$')),
      );
      final traceId = (headers['traceparent'] as String).split('-')[1];
      expect(headers['X-Trace-Id'], traceId);
    });

    test(
      'lastTraceId is empty before a request, then the latest one',
      () async {
        final adapter = _ok();
        final client = _client(adapter);
        expect(client.lastTraceId, isNull);

        await client.value('/a', decode: _echo);
        final first = client.lastTraceId;
        expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(adapter.requests.single.headers['X-Trace-Id'], first);

        await client.value('/b', decode: _echo);
        expect(client.lastTraceId, isNot(first));
      },
    );

    test('a failed request is remembered too', () async {
      final adapter = FakeAdapter((_) => FakeAdapter.json(500, {'x': 1}));
      final client = _client(adapter);
      await client
          .value('/a', decode: _echo)
          .then<void>((_) {}, onError: (_) {});
      expect(client.lastTraceId, adapter.requests.single.headers['X-Trace-Id']);
    });

    test('a traceparent the caller set is kept, and its trace id is the one remembered', () async {
      final adapter = _ok();
      final client = _client(adapter);
      const given = '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';
      await client.value('/a', decode: _echo, headers: {'traceparent': given});

      expect(adapter.requests.single.headers['traceparent'], given);
      expect(client.lastTraceId, '0af7651916cd43dd8448eb211c80319c');
    });
  });
}
