import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../social_support.dart';
import 'form_page.dart';

/// `ApiError.code`s of linking that this screen words (kotlin `account`).
const _identityTaken = 'ACCOUNT.IDENTITY_TAKEN';
const _identityExists = 'ACCOUNT.IDENTITY_EXISTS';

/// Settings, "Social sign-in": which providers are linked to this account and
/// a button to link another one. The server wants a proof first, the one that
/// fits the account: the password, a code mailed to its address, or (no
/// address) a fresh sign-in with a provider that is already linked.
class SocialLinkScreen extends ConsumerStatefulWidget {
  const SocialLinkScreen({super.key});

  @override
  ConsumerState<SocialLinkScreen> createState() => _SocialLinkScreenState();
}

class _SocialLinkScreenState extends ConsumerState<SocialLinkScreen> {
  String? _busyId;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(sampleAccountProvider);
    final providers = ref.watch(availableSocialProvidersProvider).value;
    return FormPage(
      title: 'Social sign-in',
      children: [
        account.when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(
            message: 'Could not load your account.',
            onRetry: () => ref.invalidate(sampleAccountProvider),
          ),
          data: (account) {
            if (providers == null || providers.isEmpty) {
              return const Text('No social sign-in is available.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final provider in providers)
                  ListTile(
                    title: Text(_name(provider.id)),
                    trailing: account.methods.contains(provider.id)
                        ? const Text('Linked')
                        : OutlinedButton(
                            key: ValueKey('social.link.${provider.id}'),
                            onPressed: _busyId == null
                                ? () => _link(provider, account)
                                : null,
                            child: const Text('Link'),
                          ),
                  ),
              ],
            );
          },
        ),
        if (_message != null) ...[
          const SizedBox(height: SkeletonSpace.sm),
          Text(_message!, key: const ValueKey('social.link.message')),
        ],
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/settings'),
          child: const Text('Back'),
        ),
      ],
    );
  }

  static String _name(String id) => '${id[0].toUpperCase()}${id.substring(1)}';

  Future<void> _link(SocialProvider provider, SampleAccount account) async {
    final api = ref.read(socialAuthApiProvider);
    setState(() {
      _busyId = provider.id;
      _message = null;
    });
    try {
      // The proof first: the server checks it before it looks at the token.
      final proof = await _proof(account);
      if (proof == null) return;
      final credential = await provider.obtain(generateSocialNonce());
      await api.link(provider.id, credential, proof: proof);
      ref.invalidate(sampleAccountProvider);
      _show('${_name(provider.id)} is linked.');
    } on SocialCancelled {
      // The person backed out: nothing to say.
    } on ApiRequestError catch (e) {
      _show(_errorText(e));
    } catch (e, stackTrace) {
      _show(socialFailureText(SocialFailure.sdk));
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: 'sample',
          context: ErrorDescription('while linking ${provider.id}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// The proof fields of the link call; null = the person backed out.
  Future<Map<String, Object?>?> _proof(SampleAccount account) async {
    if (account.hasPassword) {
      final password = await _ask('Your password', obscure: true);
      return password == null ? null : {'currentPassword': password};
    }
    if (account.email != null) {
      await ref
          .read(apiClientProvider)
          .value(
            '/account/reauth/confirmation',
            method: 'POST',
            decode: (json) => json,
          );
      final code = await _ask('The code we emailed you');
      return code == null ? null : {'confirmationCode': code};
    }
    final reauth = await reauthWithLinkedProvider(ref);
    return reauth == null ? null : {'socialReauth': reauth};
  }

  Future<String?> _ask(String label, {bool obscure = false}) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return text == null || text.isEmpty ? null : text;
  }

  void _show(String message) {
    if (mounted) setState(() => _message = message);
  }

  static String _errorText(ApiRequestError e) => switch (e.code) {
    _identityTaken =>
      'That account is already linked to another account here. Sign in with '
          'it, remove the link in its settings, then try again.',
    _identityExists => 'This provider is already linked.',
    AccountErrorCodes.currentPasswordInvalid => 'The password is wrong.',
    AccountErrorCodes.codeInvalid => 'The code is wrong.',
    AccountErrorCodes.codeExpired => 'The code has expired. Try again.',
    AccountErrorCodes.reauthFailed ||
    AccountErrorCodes.reauthRequired => 'We could not confirm it is you.',
    _ => socialFailureText(socialFailureOf(e)),
  };
}
