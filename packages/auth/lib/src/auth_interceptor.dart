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
/// - The new pair is saved before the call is repeated.
/// - `AUTH.REFRESH_INVALID` / `AUTH.REFRESH_REUSED`: the store is cleared and
///   [onSessionEnded] runs once; the original 401 is returned to the caller.
/// - Any other refresh failure (network, 5xx, 429) says nothing about the
///   session: it stays, and the caller gets that error.
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
  });

  final Dio dio;
  final TokenStore store;
  final Future<AuthResult> Function(String refreshToken) refresh;
  final FutureOr<void> Function() onSessionEnded;

  static const _retriedKey = 'authRetried';

  Future<_Outcome>? _inFlight;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra[ApiClient.skipAuthKey] == true ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final outcome = await _recover(_bearerOf(options));
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
    return _inFlight ??= _refreshOnce(failedToken)
        .whenComplete(() => _inFlight = null);
  }

  Future<_Outcome> _refreshOnce(String? failedToken) async {
    final stored = await store.read();
    // Signed out already: nothing to renew.
    if (stored == null) {
      return const _Ended();
    }
    // Another call renewed the token meanwhile.
    if (failedToken != null && failedToken != stored.accessToken) {
      return _Refreshed(stored.accessToken);
    }
    try {
      final result = await refresh(stored.refreshToken);
      await store.save(result.tokens);
      return _Refreshed(result.tokens.accessToken);
    } on ApiRequestError catch (e) {
      if (e.code == ErrorCodes.authRefreshInvalid ||
          e.code == ErrorCodes.authRefreshReused) {
        await store.clear();
        await onSessionEnded();
        return const _Ended();
      }
      return _Failed(e);
    }
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
