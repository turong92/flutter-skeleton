import 'dart:async';

import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

/// What `createAuthClient` builds, assembled by hand so a test can shorten the
/// refresh retry waits (they are not a public setting).
ApiClient testAuthClient({
  required TokenStore store,
  required HttpClientAdapter adapter,
  FutureOr<void> Function()? onSessionEnded,
  List<Duration> retryDelays = const [Duration.zero],
}) {
  final client = ApiClient(
    baseUrl: 'http://localhost:8080/api/v1',
    adapter: adapter,
    headerProviders: [
      () async {
        final tokens = await store.read();
        return {
          if (tokens != null) 'Authorization': 'Bearer ${tokens.accessToken}',
        };
      },
    ],
  );
  client.dio.interceptors.add(
    AuthInterceptor(
      dio: client.dio,
      store: store,
      refresh: AuthApi(client).refresh,
      onSessionEnded: onSessionEnded ?? () {},
      retryDelays: retryDelays,
    ),
  );
  return client;
}
