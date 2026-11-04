import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A scripted backend: every request goes through [handler], which returns the
/// response (build it with [FakeAdapter.json]) or throws a [DioException].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  static ResponseBody json(
    int status,
    Object? body, {
    Map<String, List<String>>? headers,
  }) {
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...?headers,
      },
    );
  }

  static ResponseBody empty(int status) => ResponseBody.fromString('', status);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
