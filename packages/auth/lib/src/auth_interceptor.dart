import 'dart:async';

import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';
import 'token_store.dart';

/// Renews the access token when the backend answers 401, and repeats the call.
///
/// - **One refresh at a time.** Calls that fail together share one in-flight
///   refresh ([_inFlight]); a call that failed with an older token than the one
///   now stored just repeats with the stored one. The refresh token rotates on
///   every use and a reused one closes the whole session, so a second refresh
///   with the old token would sign the user out.
/// - The new pair is saved before the call is repeated, but only if the store
///   still holds the refresh token that was sent. A sign-out or a new sign-in
///   during the refresh wins: the stale result is dropped.
/// - **The session ends** (store cleared, [onSessionEnded] once, the original
///   401 goes to the caller) on a 401 carrying an `AUTH.*` code
///   (`REFRESH_INVALID`, `REFRESH_REUSED`, ...), on `403 AUTH.ACCOUNT_SUSPENDED`,
///   and after five 401s in a row without an `AUTH.*` code (not the backend).
/// - **A lost response is sent again with the SAME refresh token** while the
///   failure is transient (no response, 408, 429, 5xx, a 401 without an `AUTH.*`
///   code): the backend's `reuse-grace` hands the same successor to the same
///   token. Waits are 2, 4, 8, 16, then 30 s (at most grace / 2 for the
///   recommended 60 s). The waiting happens inside the shared flight; a caller
///   waits at most 45 s and then gets a network error while the flight goes on.
/// - Any other failure (including `429 AUTH.TOO_MANY_REFRESHES`, where the
///   session is fine) goes to the caller as it is; the session stays.
/// - A repeated call is not recovered twice. Requests marked `skipAuth`
///   (login, refresh, logout) are left alone.
///
/// A plain [Interceptor], not a `QueuedInterceptor`: repeating a call through
/// the same Dio from inside a queued `onError` waits on its own queue.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.store,
    required this.refresh,
    required this.onSessionEnded,
    this.retryDelays = defaultRetryDelays,
  });

  static const defaultRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  /// Codeless 401s in a row after which the session is treated as ended.
  static const _maxCodeless401 = 5;

  /// How long one call waits for the shared refresh flight.
  static const _waitLimit = Duration(seconds: 45);
  static const _retriedKey = 'authRetried';

  final Dio dio;
  final TokenStore store;
  final Future<AuthResult> Function(String refreshToken) refresh;
  final FutureOr<void> Function() onSessionEnded;

  /// Waits between sends of a transient-failing refresh; the last one repeats.
  final List<Duration> retryDelays;

  Future<_Outcome>? _inFlight;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra[ApiClient.skipAuthKey] == true ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final outcome = await _recover(_bearerOf(options)).timeout(
      _waitLimit,
      onTimeout: () => _Failed(
        ApiRequestError.network(detail: 'session refresh is taking too long'),
      ),
    );
    switch (outcome) {
      case _Refreshed(:final accessToken):
        final retry = options.copyWith(
          headers: {...options.headers, 'Authorization': 'Bearer $accessToken'},
          extra: {...options.extra, _retriedKey: true},
        );
        try {
          handler.resolve(await dio.fetch<Object?>(retry));
        } on DioException catch (e) {
          handler.next(e);
        }
      case _Ended():
        handler.next(err);
      case _Failed(:final error):
        handler.reject(DioException(requestOptions: options, error: error));
    }
  }

  String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    return header is String && header.startsWith('Bearer ')
        ? header.substring(7)
        : null;
  }

  Future<_Outcome> _recover(String? failedToken) {
    return _inFlight ??= _flight(failedToken)
        .whenComplete(() => _inFlight = null);
  }

  Future<_Outcome> _flight(String? failedToken) async {
    String? sentToken;
    var codeless401 = 0;
    for (var attempt = 0; ; attempt++) {
      final stored = await store.read();
      // Signed out already: nothing to renew.
      if (stored == null) return const _Ended();
      if (attempt == 0) {
        // Another call renewed the token meanwhile.
        if (failedToken != null && failedToken != stored.accessToken) {
          return _Refreshed(stored.accessToken);
        }
      } else if (stored.refreshToken != sentToken) {
        // Signed out and in again while we waited: that is not our session.
        return const _Ended();
      }
      sentToken = stored.refreshToken;

      try {
        final result = await refresh(sentToken);
        // The user may have signed out or in while the request was out.
        final now = await store.read();
        if (now == null || now.refreshToken != sentToken) {
          return const _Ended();
        }
        await store.save(result.tokens);
        return _Refreshed(result.tokens.accessToken);
      } on ApiRequestError catch (e) {
        final authCode = e.code.startsWith('AUTH.');
        codeless401 = e.status == 401 && !authCode ? codeless401 + 1 : 0;
        final ends =
            e.code == ErrorCodes.authAccountSuspended ||
            (e.status == 401 && authCode) ||
            codeless401 >= _maxCodeless401;
        if (ends) {
          // A sign-out or a newer sign-in may have happened while the request
          // was out: only a session that still holds the sent token is ended.
          final now = await store.read();
          if (now == null || now.refreshToken != sentToken) {
            return const _Ended();
          }
          await store.clear();
          await onSessionEnded();
          return const _Ended();
        }
        if (!_isTransient(e)) return _Failed(e);
      }
      await Future<void>.delayed(
        retryDelays[attempt < retryDelays.length
            ? attempt
            : retryDelays.length - 1],
      );
    }
  }

  /// A failure that says nothing about the session: the answer was not given
  /// (or not by the backend).
  bool _isTransient(ApiRequestError e) {
    if (e.code == ErrorCodes.authTooManyRefreshes) return false;
    return e.status == 0 ||
        e.status == 408 ||
        e.status == 429 ||
        e.status >= 500 ||
        (e.status == 401 && !e.code.startsWith('AUTH.'));
  }
}

sealed class _Outcome {
  const _Outcome();
}

class _Refreshed extends _Outcome {
  const _Refreshed(this.accessToken);
  final String accessToken;
}

class _Ended extends _Outcome {
  const _Ended();
}

class _Failed extends _Outcome {
  const _Failed(this.error);
  final ApiRequestError error;
}
