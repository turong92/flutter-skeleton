import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

/// One server-sent event. [data] is the `data:` lines joined with `\n`.
class SseEvent {
  const SseEvent({this.id, required this.event, required this.data});

  final String? id;

  /// The `event:` name; `message` when the frame has none. The notification
  /// SSE module puts the notification type here.
  final String event;
  final String data;
}

/// The `GET /notifications/sse` stream of the kotlin-skeleton
/// `notification-sse` module, opened through the app's own [Dio] so the Bearer
/// header and the token refresh interceptor apply as they do to any call.
///
/// Every event but the server's greeting (`connected`) goes to [onEvent]; what
/// an event means is the caller's business. A dropped or silent connection
/// (no bytes for [idleTimeout]) is opened again after 1 s, doubling to 30 s,
/// plus jitter. A 404 means the server has no SSE module: it is not tried
/// again by this object. After [close] nothing is ever opened again.
class SseConnection {
  SseConnection({
    required this.dio,
    required this.onEvent,
    this.idleTimeout = const Duration(seconds: 45),
  });

  /// Its baseUrl is the API root (`.../api/v1`), as for the other packages.
  final Dio dio;
  final void Function(SseEvent event) onEvent;

  /// The sample server beats every 15 s; three missed beats is a dead line.
  /// Kept here, not in Dio's `receiveTimeout`, which is off for this call.
  final Duration idleTimeout;

  static const _path = '/notifications/sse';
  static const _firstDelay = Duration(seconds: 1);
  static const _maxDelay = Duration(seconds: 30);
  final _random = Random();

  bool _closed = false;
  bool _notFound = false;
  int _generation = 0;
  bool _running = false;
  void Function()? _abort;

  /// Connects (and keeps connecting) until [stop], [close] or a 404. Calling it
  /// while running does nothing.
  void start() {
    if (_closed || _notFound || _running) return;
    _running = true;
    unawaited(_run(++_generation));
  }

  /// Drops the connection; [start] may open it again.
  void stop() {
    _running = false;
    _generation++;
    _abort?.call();
  }

  /// [stop], for good.
  void close() {
    _closed = true;
    stop();
  }

  Future<void> _run(int generation) async {
    var delay = _firstDelay;
    while (generation == _generation) {
      final received = await _connectOnce(generation);
      if (generation != _generation) return;
      if (_notFound) {
        _running = false;
        return;
      }
      if (received) delay = _firstDelay;
      await _wait(
        delay +
            Duration(milliseconds: _random.nextInt(delay.inMilliseconds ~/ 4)),
      );
      delay = delay * 2 > _maxDelay ? _maxDelay : delay * 2;
    }
  }

  /// One connection until it ends for any reason. True if bytes arrived.
  Future<bool> _connectOnce(int generation) async {
    final token = CancelToken();
    final ended = Completer<void>();
    StreamSubscription<String>? subscription;
    Timer? idle;
    var received = false;

    void end() {
      idle?.cancel();
      unawaited(subscription?.cancel());
      token.cancel();
      if (!ended.isCompleted) ended.complete();
    }

    void arm() {
      idle?.cancel();
      idle = Timer(idleTimeout, end);
    }

    _abort = end;
    arm();
    try {
      final response = await dio.get<ResponseBody>(
        _path,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: {Headers.acceptHeader: 'text/event-stream'},
          receiveTimeout: Duration.zero,
        ),
      );
      if (ended.isCompleted || generation != _generation) {
        end();
        return received;
      }
      final parser = _FrameParser(onEvent);
      subscription = response.data!.stream
          .map((bytes) {
            received = true;
            arm();
            return bytes;
          })
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            parser.line,
            onError: (Object _) => end(),
            onDone: end,
            cancelOnError: true,
          );
      await ended.future;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) _notFound = true;
    } finally {
      idle?.cancel();
      token.cancel();
      if (_abort == end) _abort = null;
    }
    return received;
  }

  /// Sleeps [duration]; [stop] wakes it early.
  Future<void> _wait(Duration duration) {
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    _abort = () {
      timer.cancel();
      if (!done.isCompleted) done.complete();
    };
    return done.future;
  }
}

/// Collects lines into frames: a blank line ends one.
class _FrameParser {
  _FrameParser(this._emit);

  final void Function(SseEvent) _emit;
  final _data = <String>[];
  String? _id;
  String? _event;

  void line(String line) {
    if (line.isEmpty) {
      _dispatch();
      return;
    }
    if (line.startsWith(':')) return; // comment, heartbeat
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'data':
        _data.add(value);
      case 'event':
        _event = value;
      case 'id':
        _id = value;
    }
  }

  void _dispatch() {
    final data = _data.join('\n');
    final event = _event ?? 'message';
    final id = _id;
    final had = _data.isNotEmpty;
    _data.clear();
    _event = null;
    // `id` carries over to later frames, as the SSE spec says.
    if (!had || event == 'connected') return;
    _emit(SseEvent(id: id, event: event, data: data));
  }
}
