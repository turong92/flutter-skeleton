import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_social_login_naver/skeleton_social_login_naver.dart';

const _secretToken = 'naver-access-token-secret';
const _channel = MethodChannel('flutter_naver_login');

Map<String, Object?> _tokenMap(String accessToken) => {
  'accessToken': {
    'accessToken': accessToken,
    'refreshToken': 'naver-refresh-token-secret',
    'expiresAt': '2099-01-01 00:00:00',
    'tokenType': 'bearer',
  },
};

/// The native side answers [logIn] with [loginAnswer] and the token call with
/// [tokenAnswer]. Returns the method names called, in order.
List<String> _fakeNative({
  required Map<String, Object?> loginAnswer,
  Map<String, Object?>? tokenAnswer,
}) {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'logIn' => loginAnswer,
          'getCurrentAccessToken' => tokenAnswer,
          _ => null,
        };
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the credential carries the access token and prints none of it',
    () async {
      final calls = _fakeNative(
        loginAnswer: {'status': 'loggedIn'},
        tokenAnswer: _tokenMap(_secretToken),
      );
      final provider = NaverSocialProvider();

      final credential = await provider.obtain('nonce');

      expect(provider.id, 'naver');
      expect(calls, ['logIn', 'getCurrentAccessToken']);
      expect(credential.toJson(), {'accessToken': _secretToken});
      expect('$credential', isNot(contains(_secretToken)));
    },
  );

  test('Android reports a back-out as loggedOut, iOS as an error that says '
      'cancelled: both are SocialCancelled', () async {
    _fakeNative(loginAnswer: {'status': 'loggedOut'});
    await expectLater(
      NaverSocialProvider().obtain('n'),
      throwsA(isA<SocialCancelled>()),
    );

    _fakeNative(
      loginAnswer: {
        'status': 'error',
        'errorMessage': 'Login cancelled by user',
      },
    );
    await expectLater(
      NaverSocialProvider().obtain('n'),
      throwsA(isA<SocialCancelled>()),
    );
  });

  test('a failure is an exception that holds no token', () async {
    _fakeNative(
      loginAnswer: {
        'status': 'error',
        'errorMessage': 'errorCode:server_error',
      },
    );
    await expectLater(
      NaverSocialProvider().obtain('n'),
      throwsA(
        isA<Exception>().having(
          (e) => '$e',
          'message',
          allOf(contains('server_error'), isNot(contains('secret'))),
        ),
      ),
    );

    // Signed in, but the SDK has no token to give: still an exception, and
    // the message never prints the (empty or not) token object.
    _fakeNative(loginAnswer: {'status': 'loggedIn'}, tokenAnswer: null);
    await expectLater(
      NaverSocialProvider().obtain('n'),
      throwsA(isA<Exception>()),
    );
  });
}
