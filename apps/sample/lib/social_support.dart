import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_social_login_apple/skeleton_social_login_apple.dart';
import 'package:skeleton_social_login_google/skeleton_social_login_google.dart';
import 'package:skeleton_social_login_kakao/skeleton_social_login_kakao.dart';
import 'package:skeleton_social_login_naver/skeleton_social_login_naver.dart';

import 'config.dart';

/// The providers this build has: Google and Kakao only with their value set,
/// Apple on iOS, Naver always (its values live in the native files). The
/// server's `GET /auth/methods` then decides which ones are shown.
///
/// One instance each, for the life of the app: Google's SDK may be
/// initialised once per run.
List<SocialProvider> buildSocialProviders() {
  final apple = AppleSocialProvider();
  return [
    if (AppConfig.googleServerClientId.isNotEmpty)
      GoogleSocialProvider(
        serverClientId: AppConfig.googleServerClientId,
        clientId: AppConfig.googleIosClientId.isEmpty
            ? null
            : AppConfig.googleIosClientId,
      ),
    if (apple.isVisible) apple,
    if (AppConfig.kakaoNativeAppKey.isNotEmpty) KakaoSocialProvider(),
    NaverSocialProvider(),
  ];
}

/// `GET /account/me`, reduced to what the sample needs: which proof the
/// account can give and which sign-in methods it has. `/account/me` is on the
/// server's allow list for accounts without an address, `/account/identities`
/// is not.
class SampleAccount {
  const SampleAccount({
    required this.hasPassword,
    required this.email,
    required this.methods,
    this.appleToRevoke,
  });

  final bool hasPassword;
  final String? email;

  /// The `method` of every sign-in method (`password`, `google`, `apple`, ...).
  final Set<String> methods;

  /// Set when the account has an Apple sign-in and this build has the Apple
  /// provider: Apple must be told to drop its access before the account is
  /// deleted.
  final AppleSocialProvider? appleToRevoke;
}

final sampleAccountProvider = FutureProvider.autoDispose<SampleAccount>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  final providers = ref.watch(socialProvidersProvider);
  final account = await client.value('/account/me', decode: (json) => json);
  final methods = {
    for (final item in [...?(account['methods'] as List?)])
      if (item is Map<String, Object?> && item['method'] is String)
        item['method']! as String,
  };
  return SampleAccount(
    hasPassword: account['hasPassword'] == true,
    email: account['email'] as String?,
    methods: methods,
    appleToRevoke: methods.contains('apple')
        ? providers.whereType<AppleSocialProvider>().firstOrNull
        : null,
  );
});

/// The proof for an account without an address (or one the person cannot
/// receive mail for): signs in again with a provider already linked to this
/// account and returns the server's `socialReauth` object. Null = the person
/// backed out.
Future<Map<String, Object?>?> reauthWithLinkedProvider(WidgetRef ref) async {
  final providers = ref.read(socialProvidersProvider);
  final account = await ref.read(sampleAccountProvider.future);
  final provider = providers
      .where((p) => account.methods.contains(p.id))
      .firstOrNull;
  if (provider == null) {
    throw StateError('No linked provider can be used in this build');
  }
  try {
    final credential = await provider.obtain(generateSocialNonce());
    return SocialAuthApi.socialReauth(provider.id, credential);
  } on SocialCancelled {
    return null;
  }
}

/// The text for a failed social sign-in. A cancel never gets here.
String socialFailureText(SocialFailure failure) => switch (failure) {
  SocialFailure.emailConflict =>
    'An account with that email already exists. Sign in with that account, '
        'then link this provider in Settings.',
  SocialFailure.notLinked => 'No account is registered for this sign-in.',
  SocialFailure.tokenRejected => 'The sign-in was refused. Try again.',
  SocialFailure.providerNotAvailable => 'This sign-in is not available.',
  SocialFailure.providerDown =>
    'The sign-in service is not responding. Try again later.',
  SocialFailure.blocked => 'This account cannot sign in.',
  SocialFailure.deletionPending => 'This account is being deleted.',
  SocialFailure.mfaRequired =>
    'This account needs a second sign-in step this app does not have.',
  SocialFailure.network => 'No connection. Check the network and try again.',
  SocialFailure.sdk => 'The sign-in failed. Try again.',
  SocialFailure.other => 'Something went wrong. Try again.',
};
