import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'social_auth_api.dart';
import 'social_credential.dart';
import 'social_failure.dart';

/// The providers this app has linked in (`google`, `apple`, ...). The app
/// overrides it with the provider packages it uses.
final socialProvidersProvider = Provider<List<SocialProvider>>(
  (ref) => throw UnimplementedError(
    'Override socialProvidersProvider in the ProviderScope',
  ),
);

final socialAuthApiProvider = Provider<SocialAuthApi>(
  (ref) => SocialAuthApi(ref.watch(apiClientProvider)),
);

/// The providers to show as buttons: the app's own, minus those the server did
/// not list with a `nativeToken` in `GET /auth/methods`.
final availableSocialProvidersProvider = FutureProvider<List<SocialProvider>>((
  ref,
) async {
  final ids = await ref.watch(socialAuthApiProvider).nativeTokenProviders();
  return [
    for (final provider in ref.watch(socialProvidersProvider))
      if (ids.contains(provider.id)) provider,
  ];
});

/// Ends every provider SDK session on sign-out:
/// `ref.read(signOutHooksProvider).add(ref.read(socialSignOutHookProvider))`.
final socialSignOutHookProvider = Provider<Future<void> Function()>((ref) {
  final providers = ref.watch(socialProvidersProvider);
  return () => Future.wait([for (final p in providers) p.signOut()]);
});

sealed class SocialLoginState {
  const SocialLoginState();
}

class SocialLoginIdle extends SocialLoginState {
  const SocialLoginIdle();
}

/// The SDK or the server is being asked. Disable the buttons.
class SocialLoginBusy extends SocialLoginState {
  const SocialLoginBusy(this.providerId);

  final String providerId;
}

class SocialLoginFailed extends SocialLoginState {
  const SocialLoginFailed(this.providerId, this.failure, {this.error});

  final String providerId;

  /// Pick the text from this.
  final SocialFailure failure;

  /// The server's answer when there was one (code, status, trace id).
  final ApiRequestError? error;

  @override
  String toString() => 'SocialLoginFailed($providerId, ${failure.name})';
}

final socialLoginControllerProvider =
    NotifierProvider<SocialLoginController, SocialLoginState>(
      SocialLoginController.new,
    );

class SocialLoginController extends Notifier<SocialLoginState> {
  @override
  SocialLoginState build() => const SocialLoginIdle();

  /// Gets the provider's token, has the server check it, and only then signs
  /// in. The state ends at [SocialLoginIdle] (signed in, or the person
  /// cancelled) or [SocialLoginFailed]; a call while busy is ignored.
  Future<void> signIn(SocialProvider provider) async {
    if (state is SocialLoginBusy) return;
    state = SocialLoginBusy(provider.id);
    try {
      final credential = await provider.obtain(generateSocialNonce());
      final result = await ref
          .read(socialAuthApiProvider)
          .login(provider.id, credential);
      await ref.read(authSessionProvider.notifier).signInWith(result);
      _set(const SocialLoginIdle());
    } on SocialCancelled {
      _set(const SocialLoginIdle());
    } on ApiRequestError catch (e) {
      // A right proof for an account in its deletion grace: hand the offer to
      // cancel to the auth package's [pendingDeletionProvider]. The failure
      // keeps no error, so the restore token is not carried here.
      final pending = deletionPendingOf(e);
      if (pending != null) {
        ref.read(pendingDeletionProvider.notifier).set(pending);
        _set(SocialLoginFailed(provider.id, SocialFailure.deletionPending));
        return;
      }
      _set(SocialLoginFailed(provider.id, socialFailureOf(e), error: e));
    } catch (e, stackTrace) {
      // The SDK failed or the app is broken: show the generic text and make
      // it visible. The exception is reported as is; this package never puts
      // a token into one.
      _set(SocialLoginFailed(provider.id, SocialFailure.sdk));
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: 'skeleton_social_login',
          context: ErrorDescription('while signing in with ${provider.id}'),
        ),
      );
    }
  }

  void _set(SocialLoginState next) {
    if (ref.mounted) state = next;
  }
}
