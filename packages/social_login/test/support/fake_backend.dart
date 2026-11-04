import 'package:dio/dio.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

/// A stand-in for the social part of the backend: the token login and
/// `GET /auth/methods`.
class FakeSocialBackend {
  /// When set, the token login answers this `(status, code)`.
  (int, String)? loginError;

  /// `social[]` of `GET /auth/methods`.
  List<Map<String, Object?>> methodsSocial = [];

  final List<RequestOptions> requests = [];

  late final FakeAdapter adapter = FakeAdapter((options) {
    requests.add(options);
    if (options.path.endsWith('/token')) {
      final error = loginError;
      if (error != null) {
        return FakeAdapter.json(error.$1, {
          'code': error.$2,
          'title': error.$2,
          'status': error.$1,
          'timestamp': '2026-01-01T00:00:00Z',
        });
      }
      return FakeAdapter.json(200, {
        'value': {
          'accessToken': 'access-1',
          'tokenType': 'Bearer',
          'expiresAt': '2026-01-01T00:15:00Z',
          'principal': {
            'accountId': 'acc_user',
            'roles': ['USER'],
            'permissions': <String>[],
          },
          'refreshToken': 'refresh-1',
          'refreshExpiresAt': '2026-02-01T00:00:00Z',
          'sessionId': 'sid_1',
        },
        'meta': _meta,
      });
    }
    if (options.path == '/auth/methods') {
      return FakeAdapter.json(200, {
        'value': {
          'methods': ['password'],
          'social': methodsSocial,
        },
        'meta': _meta,
      });
    }
    return FakeAdapter.json(404, {
      'code': 'COMMON.NOT_FOUND',
      'title': 'x',
      'status': 404,
      'timestamp': '2026-01-01T00:00:00Z',
    });
  });
}

/// A provider that hands out the token it was built with, or cancels.
class FakeSocialProvider implements SocialProvider {
  FakeSocialProvider(this.id, {this.idToken, this.accessToken});

  @override
  final String id;
  final String? idToken;
  final String? accessToken;

  bool cancel = false;
  String? lastNonce;
  int signOuts = 0;

  @override
  Future<SocialCredential> obtain(String nonce) async {
    lastNonce = nonce;
    if (cancel) throw const SocialCancelled();
    return idToken != null
        ? SocialCredential.idToken(idToken!, nonce: nonce)
        : SocialCredential.accessToken(accessToken!);
  }

  @override
  Future<void> signOut() async => signOuts++;
}
