import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_realtime/skeleton_realtime.dart';
import 'package:test/test.dart';

/// A server whose streams the test feeds by hand.
class _Server {
  final streams = <StreamController<Uint8List>>[];
  int status = 200;

  late final adapter = FakeAdapter((options) {
    if (status != 200) return FakeAdapter.empty(status);
    final controller = StreamController<Uint8List>();
    streams.add(controller);
    return ResponseBody(
      controller.stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  });

  void send(String text, {int stream = 0}) =>
      streams[stream].add(Uint8List.fromList(utf8.encode(text)));
}

void main() {
  late _Server server;
  late List<SseEvent> events;
  late SseConnection connection;

  void setUp0(FakeAsync async, {int status = 200}) {
    server = _Server()..status = status;
    events = [];
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
      ..httpClientAdapter = server.adapter;
    connection = SseConnection(dio: dio, onEvent: events.add);
    connection.start();
    async.elapse(const Duration(milliseconds: 10)); // Dio's zero-delay hops
  }

  test(
    'parses multi-line data, id and event; skips comments and connected',
    () {
      fakeAsync((async) {
        setUp0(async);
        expect(server.adapter.requests.single.path, '/notifications/sse');
        server.send(
          'event: connected\ndata: {}\n\n'
          ': heartbeat\n\n'
          'id: 7\nevent: COMMENT\ndata: {"a":\ndata: 1}\n\n',
        );
        async.flushMicrotasks();

        expect(events, hasLength(1));
        expect(events.single.id, '7');
        expect(events.single.event, 'COMMENT');
        expect(events.single.data, '{"a":\n1}');
        connection.close();
      });
    },
  );

  test('a 404 means the server has no SSE: it does not connect again', () {
    fakeAsync((async) {
      setUp0(async, status: 404);
      async.elapse(const Duration(minutes: 5));

      expect(server.adapter.requests, hasLength(1));
      connection.start();
      async.elapse(const Duration(minutes: 5));
      expect(server.adapter.requests, hasLength(1));
    });
  });

  test('no bytes for idleTimeout cuts the connection and connects again', () {
    fakeAsync((async) {
      setUp0(async);
      async.elapse(const Duration(seconds: 44));
      expect(server.adapter.requests, hasLength(1));

      async.elapse(
        const Duration(seconds: 3),
      ); // idle cut at 45 s, retry after 1-1.25 s
      expect(server.adapter.requests, hasLength(2));
      connection.close();
    });
  });

  test('a heartbeat comment keeps the connection', () {
    fakeAsync((async) {
      setUp0(async);
      for (var i = 0; i < 6; i++) {
        async.elapse(const Duration(seconds: 15));
        server.send(': \n\n');
      }
      expect(server.adapter.requests, hasLength(1));
      connection.close();
    });
  });

  test('after close it never connects again, even when the stream drops', () {
    fakeAsync((async) {
      setUp0(async);
      connection.close();
      server.streams.single.close();
      async.elapse(const Duration(minutes: 5));
      connection.start();
      async.elapse(const Duration(minutes: 5));

      expect(server.adapter.requests, hasLength(1));
    });
  });
}
