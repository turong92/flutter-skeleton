import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sign_in_with_apple_platform_interface/sign_in_with_apple_platform_interface.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_social_login_apple/skeleton_social_login_apple.dart';

const _rawNonce = 'raw-nonce-value-0123456789';
const _identityToken = 'eyJ.identity-token-secret.sig';
const _authCode = 'c.authorization-code-secret';

class _FakeApple extends SignInWithApplePlatform
    with MockPlatformInterfaceMixin {
  String? nonceGiven;
  Object? error;
  String? identityToken = _identityToken;

  @override
  Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    WebAuthenticationOptions? webAuthenticationOptions,
    String? nonce,
    String? state,
  }) async {
    nonceGiven = nonce;
    if (error != null) throw error!;
    return AuthorizationCredentialAppleID(
      userIdentifier: 'user-1',
      givenName: 'Ada',
      familyName: 'Lovelace',
      email: 'ada@example.com',
      authorizationCode: _authCode,
      identityToken: identityToken,
      state: null,
    );
  }
}

void main() {
  late _FakeApple fake;
  late AppleSocialProvider provider;

  setUp(() {
    fake = _FakeApple();
    SignInWithApplePlatform.instance = fake;
    provider = AppleSocialProvider(isIOS: () => true);
  });

  test(
    'the SDK gets sha256 of the nonce and the server gets the raw one',
    () async {
      final credential = await provider.obtain(_rawNonce);

      expect(
        fake.nonceGiven,
        sha256.convert(utf8.encode(_rawNonce)).toString(),
      );
      expect(fake.nonceGiven, isNot(_rawNonce));
      expect(credential.toJson(), {
        'idToken': _identityToken,
        'nonce': _rawNonce,
        'displayName': 'Ada Lovelace',
      });
    },
  );

  test(
    'no token or code shows in toString or in a missing-token error',
    () async {
      final credential = await provider.obtain(_rawNonce);
      expect(credential.toString(), isNot(contains(_identityToken)));

      fake.identityToken = null;
      Object? error;
      try {
        await provider.obtain(_rawNonce);
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect('$error', isNot(contains(_authCode)));
    },
  );

  test('backing out of the Apple sheet is SocialCancelled', () async {
    fake.error = const SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.canceled,
      message: 'canceled',
    );

    expect(provider.obtain(_rawNonce), throwsA(isA<SocialCancelled>()));
  });
}
