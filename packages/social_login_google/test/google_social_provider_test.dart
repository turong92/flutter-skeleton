import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_social_login_google/skeleton_social_login_google.dart';

const _idToken = 'eyJ.google-id-token-secret.sig';

class _FakeGoogle extends GoogleSignInPlatform with MockPlatformInterfaceMixin {
  InitParameters? initParams;
  int initCalls = 0;
  GoogleSignInException? error;
  String? idToken = _idToken;

  @override
  Future<void> init(InitParameters params) async {
    initCalls++;
    initParams = params;
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    if (error != null) throw error!;
    return AuthenticationResults(
      user: const GoogleSignInUserData(email: 'ada@example.com', id: 'g-1'),
      authenticationTokens: AuthenticationTokenData(idToken: idToken),
    );
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _FakeGoogle fake;
  late GoogleSocialProvider provider;

  setUp(() {
    fake = _FakeGoogle();
    GoogleSignInPlatform.instance = fake;
    provider = GoogleSocialProvider(
      serverClientId: 'web-client.apps.example.com',
    );
  });

  test('initializes once with the web client id and no nonce', () async {
    await provider.obtain('raw-nonce-value-0123456789');
    await provider.obtain('another-nonce-value-0123456');

    expect(fake.initCalls, 1);
    expect(fake.initParams!.serverClientId, 'web-client.apps.example.com');
    expect(fake.initParams!.nonce, isNull);
  });

  test('returns the ID token without a nonce, and prints no value', () async {
    final credential = await provider.obtain('raw-nonce-value-0123456789');

    expect(credential.toJson(), {'idToken': _idToken});
    expect(credential.toString(), isNot(contains(_idToken)));
  });

  test('a missing ID token fails without naming a value', () async {
    fake.idToken = null;
    Object? error;
    try {
      await provider.obtain('raw-nonce-value-0123456789');
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull);
    expect('$error', isNot(contains(_idToken)));
  });

  test('backing out of the Google sheet is SocialCancelled', () async {
    fake.error = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );

    expect(
      provider.obtain('raw-nonce-value-0123456789'),
      throwsA(isA<SocialCancelled>()),
    );
  });
}
