import 'dart:async';

import 'package:dio/dio.dart';

/// The calls a gate has refused and is holding until the person has dealt
/// with the gate (an address added, a login ID chosen). Calls that are refused
/// meanwhile share the one screen and are all released together.
///
/// [hold] is what a gate interceptor's `onRequired` returns: it completes with
/// `true` ([release] with `resend: true`: send the call again) or `false` (the
/// person left the gate: the call ends with its original 403).
class HeldCalls {
  final List<Completer<bool>> _waiting = [];

  Future<bool> hold() {
    final waiting = Completer<bool>();
    _waiting.add(waiting);
    return waiting.future;
  }

  void release({required bool resend}) {
    final done = [..._waiting];
    _waiting.clear();
    for (final waiting in done) {
      waiting.complete(resend);
    }
  }
}

/// Sends [options] again through [dio] (same headers, so the same
/// `Idempotency-Key`; the token is renewed by the auth interceptor if it went
/// stale). [mark] is set on the repeat so one gate does not hold it twice.
Future<Response<Object?>> sendHeldCallAgain(
  Dio dio,
  RequestOptions options,
  String mark,
) =>
    dio.fetch<Object?>(options.copyWith(extra: {...options.extra, mark: true}));
