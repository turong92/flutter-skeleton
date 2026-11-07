// #file social-login
import 'package:flutter_riverpod/flutter_riverpod.dart';
// #if social-login-apple
import 'package:skeleton_api_client/skeleton_api_client.dart';
// #endif
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
// #if social-login-apple
import 'package:skeleton_social_login_apple/skeleton_social_login_apple.dart';
// #endif
// #if social-login-google
import 'package:skeleton_social_login_google/skeleton_social_login_google.dart';
// #endif
// #if social-login-kakao
import 'package:skeleton_social_login_kakao/skeleton_social_login_kakao.dart';
// #endif
// #if social-login-naver
import 'package:skeleton_social_login_naver/skeleton_social_login_naver.dart';
// #endif

// #if social-login-google|social-login-kakao
import 'config.dart';
// #endif
import 'l10n/l10n.dart';

/// The providers this build has: Google and Kakao only with their value set,
/// Apple on iOS, Naver always (its values live in the native files). The
/// server's `GET /auth/methods` then decides which ones are shown.
///
/// One instance each, for the life of the app: Google's SDK may be
/// initialised once per run.
List<SocialProvider> buildSocialProviders() {
  return [
    // The providers that were picked when this project was made.
    // #if social-login-google
    if (AppConfig.googleServerClientId.isNotEmpty)
      GoogleSocialProvider(
        serverClientId: AppConfig.googleServerClientId,
        clientId: AppConfig.googleIosClientId.isEmpty
            ? null
            : AppConfig.googleIosClientId,
      ),
    // #endif
    // #if social-login-apple
    ?_visibleApple(),
    // #endif
    // #if social-login-kakao
    if (AppConfig.kakaoNativeAppKey.isNotEmpty) KakaoSocialProvider(),
    // #endif
    // #if social-login-naver
    NaverSocialProvider(),
    // #endif
  ];
}

// #if social-login-apple
/// Apple only where it can sign in (iOS).
AppleSocialProvider? _visibleApple() {
  final apple = AppleSocialProvider();
  return apple.isVisible ? apple : null;
}
// #endif

/// The sign-in methods the account has (`password`, `google`, `apple`, ...),
/// from `GET /account/me`. It is on the server's allow list for accounts
/// without an address.
final linkedMethodsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  final account = await client.value('/account/me', decode: (json) => json);
  return {
    for (final item in [...?(account['methods'] as List?)])
      if (item is Map<String, Object?> && item['method'] is String)
        item['method']! as String,
  };
});

/// The proof for an account without an address (or one the person cannot
/// receive mail for): signs in again with a provider already linked to this
/// account and returns the server's `socialReauth` object. Null = the person
/// backed out.
Future<Map<String, Object?>?> reauthWithLinkedProvider(WidgetRef ref) async {
  final providers = ref.read(socialProvidersProvider);
  final methods = await ref.read(linkedMethodsProvider.future);
  final provider = providers.where((p) => methods.contains(p.id)).firstOrNull;
  if (provider == null) {
    throw StateError('No linked provider can be used in this build');
  }
  // #if social-login-apple
  ref.read(_appleRevokeCode).code = null;
  // #endif
  try {
    final nonce = generateSocialNonce();
    // #if social-login-apple
    if (provider is AppleSocialProvider) {
      // The one Apple sheet also yields the code the revoke needs, so a
      // delete does not open Apple twice.
      final proof = await provider.obtainForDelete(nonce);
      ref.read(_appleRevokeCode).code = proof.authorizationCode;
      return SocialAuthApi.socialReauth(provider.id, proof.credential);
    }
    // #endif
    final credential = await provider.obtain(nonce);
    return SocialAuthApi.socialReauth(provider.id, credential);
  } on SocialCancelled {
    return null;
  }
}

// #if social-login-apple
/// The authorization code of the Apple sheet the delete proof opened.
class _AppleCode {
  String? code;
}

final _appleRevokeCode = Provider<_AppleCode>((ref) => _AppleCode());

/// Right before `POST /account/delete`: Apple drops its access (App Review).
/// False = the person backed out (nothing is deleted); Apple off for the
/// project (the server lists no Apple) = nothing to revoke; any other failure
/// stops the delete and the form stays.
Future<bool> revokeAppleBeforeDelete(WidgetRef ref, String unreachable) async {
  final methods = await ref.read(linkedMethodsProvider.future);
  if (!methods.contains('apple')) return true;
  final available = await ref.read(availableSocialProvidersProvider.future);
  final apple = available.whereType<AppleSocialProvider>().firstOrNull;
  if (apple == null) return true;
  final holder = ref.read(_appleRevokeCode);
  final code = holder.code;
  holder.code = null;
  try {
    final client = ref.read(apiClientProvider);
    if (code != null) {
      await apple.revokeWithCode(client, code);
    } else {
      await apple.revokeBeforeDelete(client);
    }
    return true;
  } on SocialCancelled {
    return false;
  } catch (e) {
    if (e is ApiRequestError && e.code == 'AUTH_SOCIAL.PROVIDER_NOT_FOUND') {
      return true;
    }
    throw DeleteAccountHookFailed(unreachable);
  }
}
// #endif

/// The text for a failed social sign-in. A cancel never gets here.
String socialFailureText(AppLocalizations l, SocialFailure failure) =>
    switch (failure) {
      SocialFailure.emailConflict => l.socialEmailConflict,
      SocialFailure.notLinked => l.socialNotLinked,
      SocialFailure.tokenRejected => l.socialTokenRejected,
      SocialFailure.providerNotAvailable => l.socialProviderNotAvailable,
      SocialFailure.providerDown => l.socialProviderDown,
      SocialFailure.blocked => l.socialBlocked,
      SocialFailure.deletionPending => l.socialDeletionPending,
      SocialFailure.mfaRequired => l.socialMfaRequired,
      SocialFailure.network => l.socialNetwork,
      SocialFailure.sdk => l.socialSdk,
      SocialFailure.other => l.socialOther,
    };
