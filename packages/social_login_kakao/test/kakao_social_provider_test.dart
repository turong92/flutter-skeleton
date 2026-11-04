import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_social_login_kakao/skeleton_social_login_kakao.dart';

const _secretToken = 'kakao-access-token-secret';

void main() {
  test(
    'the credential carries the access token and prints none of it',
    () async {
      final provider = KakaoSocialProvider.withSdk(
        isTalkInstalled: () async => true,
        loginWithTalk: () async => _secretToken,
        loginWithAccount: () async => fail('talk worked'),
      );

      final credential = await provider.obtain('nonce');

      expect(provider.id, 'kakao');
      expect(credential.toJson(), {'accessToken': _secretToken});
      expect('$credential', isNot(contains(_secretToken)));
    },
  );

  test('backing out of the talk login is SocialCancelled and does not fall '
      'through to the account login', () async {
    var accountOpened = false;
    final provider = KakaoSocialProvider.withSdk(
      isTalkInstalled: () async => true,
      loginWithTalk: () async =>
          throw PlatformException(code: 'CANCELED', message: 'User canceled'),
      loginWithAccount: () async {
        accountOpened = true;
        return _secretToken;
      },
    );

    await expectLater(provider.obtain('n'), throwsA(isA<SocialCancelled>()));
    expect(accountOpened, isFalse);
  });

  test(
    'another talk failure, or no talk app, goes to the Kakao account login',
    () async {
      final failing = KakaoSocialProvider.withSdk(
        isTalkInstalled: () async => true,
        loginWithTalk: () async => throw PlatformException(code: 'EUNKNOWN'),
        loginWithAccount: () async => _secretToken,
      );
      final absent = KakaoSocialProvider.withSdk(
        isTalkInstalled: () async => false,
        loginWithTalk: () async => fail('no talk app'),
        loginWithAccount: () async => _secretToken,
      );

      expect((await failing.obtain('n')).accessToken, _secretToken);
      expect((await absent.obtain('n')).accessToken, _secretToken);
    },
  );

  test('backing out of the account login is SocialCancelled', () async {
    final provider = KakaoSocialProvider.withSdk(
      isTalkInstalled: () async => false,
      loginWithTalk: () async => fail('no talk app'),
      loginWithAccount: () async =>
          throw PlatformException(code: 'CANCELED', message: 'User canceled'),
    );

    await expectLater(provider.obtain('n'), throwsA(isA<SocialCancelled>()));
  });
}
