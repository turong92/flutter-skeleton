import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:skeleton_api_client/testing.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> principalJson({
  String id = 'acc_user',
  String email = 'user@example.com',
}) => {
  'accountId': id,
  'email': email,
  'roles': ['USER'],
  'permissions': <String>[],
};

Map<String, Object?> tokenResponse(String access, String refresh) => {
  'value': {
    'accessToken': access,
    'tokenType': 'Bearer',
    'expiresAt': '2026-01-01T00:15:00Z',
    'principal': principalJson(),
    'refreshToken': refresh,
    'refreshExpiresAt': '2026-02-01T00:00:00Z',
    'sessionId': 'sid_1',
  },
  'meta': _meta,
};

ResponseBody apiError(int status, String code) => FakeAdapter.json(status, {
  'code': code,
  'title': code,
  'status': status,
  'timestamp': '2026-01-01T00:00:00Z',
});

ResponseBody ok(Object? value) =>
    FakeAdapter.json(200, {'value': value, 'meta': _meta});

/// A small stand-in for the auth backend: `GET /auth/me` wants the current
/// access token, `POST /auth/refresh` rotates it.
class FakeAuthBackend {
  FakeAuthBackend({
    this.accessToken = 'access-1',
    this.refreshToken = 'refresh-1',
    this.refreshDelay = Duration.zero,
  });

  String accessToken;
  String refreshToken;
  Duration refreshDelay;
  int _generation = 1;

  /// When set, `/auth/refresh` answers this instead of rotating.
  ResponseBody Function()? refreshOverride;
  Object? Function(Map<String, Object?> body)? loginHandler;

  final List<RequestOptions> requests = [];
  int get refreshCalls =>
      requests.where((r) => r.path == '/auth/refresh').length;
  int get meCalls => requests.where((r) => r.path == '/auth/me').length;

  late final FakeAdapter adapter = FakeAdapter(_handle);

  Future<ResponseBody> _handle(RequestOptions options) async {
    requests.add(options);
    switch (options.path) {
      case '/auth/login':
        final body = options.data as Map<String, Object?>;
        if (body['password'] != 'password') {
          return apiError(401, 'AUTH.INVALID_CREDENTIALS');
        }
        return FakeAdapter.json(200, tokenResponse(accessToken, refreshToken));
      case '/auth/me':
        if (options.headers['Authorization'] != 'Bearer $accessToken') {
          return apiError(401, 'COMMON.UNAUTHORIZED');
        }
        return ok(principalJson());
      case '/auth/refresh':
        await Future<void>.delayed(refreshDelay);
        final override = refreshOverride;
        if (override != null) return override();
        final sent = (options.data as Map<String, Object?>)['refreshToken'];
        if (sent != refreshToken) return apiError(401, 'AUTH.REFRESH_REUSED');
        _generation++;
        accessToken = 'access-$_generation';
        refreshToken = 'refresh-$_generation';
        return FakeAdapter.json(200, tokenResponse(accessToken, refreshToken));
      case '/auth/logout':
        return FakeAdapter.empty(204);
    }
    return FakeAdapter.json(
      404,
      jsonEncode({'code': 'COMMON.NOT_FOUND', 'title': 'x', 'status': 404}),
    );
  }
}
