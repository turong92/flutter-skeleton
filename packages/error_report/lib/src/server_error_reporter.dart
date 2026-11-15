import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'error_reporter.dart';

/// How a report leaves the device; replace it in tests or to send elsewhere.
/// A throw or a rejected future is ignored by the reporter.
typedef ErrorReportSend = FutureOr<void> Function(
  Uri endpoint,
  Map<String, Object?> body,
);

const _messageMax = 500;
const _stackMax = 4000;
const _maxTracked = 50;

/// Posts what the app caught to the backend's `POST /api/v1/client-errors`
/// (kotlin-skeleton `alert` module, `skeleton.alert.client-errors.enabled`,
/// off by default). It carries the error, the screen [route], the app
/// [release], the trace id of the last API request ([traceId] — the same value
/// the server log has) and how many equal errors were folded.
///
/// The report is fire and forget: offline, a refusal (429) or a failing
/// lookup is swallowed and the report dropped (no queue), an equal error
/// inside [dedupeWindow] is counted instead of sent (the first is sent at
/// once, the count rides on the next one or on [flush]), and an app run sends
/// at most [maxReports].
class ServerErrorReporter implements ErrorReporter {
  ServerErrorReporter({
    required this.endpoint,
    this.release,
    String? platform,
    this.traceId,
    this.route,
    ErrorReportSend? send,
    this.dedupeWindow = const Duration(seconds: 60),
    this.maxReports = 20,
    DateTime Function()? now,
  }) : platform = platform ?? defaultTargetPlatform.name.toLowerCase(),
       _send = send ?? _defaultSend,
       _now = now ?? DateTime.now;

  final Uri endpoint;
  final String? release;
  final String platform;

  /// The last API request's trace id (`ApiClient.lastTraceId`).
  final String? Function()? traceId;

  /// The current screen path, no query.
  final String? Function()? route;
  final Duration dedupeWindow;
  final int maxReports;
  final ErrorReportSend _send;
  final DateTime Function() _now;

  final _seen = <String, _Seen>{};
  var _sent = 0;

  @override
  void report(
    Object error,
    StackTrace? stackTrace, {
    String source = 'manual',
  }) {
    try {
      final body = _body(error, stackTrace, source);
      final key =
          '${body['name']}|${body['message']}|${_stackHead(stackTrace)}';
      final at = _now();
      final previous = _seen.remove(key);
      if (previous != null && at.difference(previous.sentAt) < dedupeWindow) {
        previous.folded += 1;
        _seen[key] = previous;
        return;
      }
      if (_seen.length >= _maxTracked) _seen.remove(_seen.keys.first);
      _seen[key] = _Seen(at, body);
      _deliver({...body, 'count': 1 + (previous?.folded ?? 0)});
    } catch (_) {
      // Reporting must never break the app.
    }
  }

  @override
  void flush() {
    try {
      for (final entry in _seen.values) {
        if (entry.folded == 0) continue;
        _deliver({...entry.body, 'count': entry.folded});
        entry.folded = 0;
      }
    } catch (_) {
      // Same.
    }
  }

  void _deliver(Map<String, Object?> body) {
    if (_sent >= maxReports) return;
    _sent += 1;
    try {
      unawaited(
        Future<void>.sync(() => _send(endpoint, body)).catchError((_) {}),
      );
    } catch (_) {
      // Dropped.
    }
  }

  Map<String, Object?> _body(Object error, StackTrace? stack, String source) {
    final isError = error is Error || error is Exception;
    return {
      'platform': platform,
      'source': source,
      'name': isError ? error.runtimeType.toString() : null,
      'message': _cut(error.toString(), _messageMax),
      'stack': stack == null ? null : _cut(stack.toString(), _stackMax),
      'route': _attempt(route),
      'release': release,
      'traceId': _attempt(traceId),
      'count': 1,
    }..removeWhere((_, value) => value == null);
  }

  static String _cut(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);

  static String? _attempt(String? Function()? read) {
    try {
      return read?.call();
    } catch (_) {
      return null;
    }
  }

  /// The first two lines of the stack tell whether it is the same error.
  static String _stackHead(StackTrace? stack) => stack == null
      ? ''
      : const LineSplitter().convert(stack.toString()).take(2).join('\n');

  static Future<void> _defaultSend(Uri endpoint, Map<String, Object?> body) =>
      _client.postUri<void>(endpoint, data: body);

  // No interceptors: a report must not trigger a token refresh or a sign-out.
  static final _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (_) => true,
    ),
  );
}

class _Seen {
  _Seen(this.sentAt, this.body);

  final DateTime sentAt;
  final Map<String, Object?> body;
  int folded = 0;
}
