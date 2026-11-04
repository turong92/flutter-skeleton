import 'dart:async';

import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'auth_api.dart';
import 'auth_interceptor.dart';
import 'token_store.dart';

/// An [ApiClient] that sends the stored access token as a Bearer header and
/// renews it on 401 (see [AuthInterceptor]).
ApiClient createAuthClient({
  required String baseUrl,
  required TokenStore tokenStore,
  required FutureOr<void> Function() onSessionEnded,
  HttpClientAdapter? adapter,
  void Function(ApiRequestError error)? onError,
  List<Duration> retryDelays = AuthInterceptor.defaultRetryDelays,
}) {
  final client = ApiClient(
    baseUrl: baseUrl,
    adapter: adapter,
    onError: onError,
    headerProviders: [
      () async {
        final tokens = await tokenStore.read();
        return {
          if (tokens != null) 'Authorization': 'Bearer ${tokens.accessToken}',
        };
      },
    ],
  );
  client.dio.interceptors.add(
    AuthInterceptor(
      dio: client.dio,
      store: tokenStore,
      refresh: AuthApi(client).refresh,
      onSessionEnded: onSessionEnded,
      retryDelays: retryDelays,
    ),
  );
  return client;
}
