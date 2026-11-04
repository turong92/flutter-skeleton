import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../social_support.dart';

/// The sign-in buttons of the providers this build has and the server lists
/// (`GET /auth/methods` with an app-token entrance). Nothing is shown while
/// that is unknown or when it fails. Backing out of a provider's sheet shows
/// nothing; a failure shows one line under the buttons.
///
/// The shapes follow each provider's guide: Apple's own button (HIG), Google
/// white or dark with its outline, Kakao yellow, Naver green. The logos are
/// not in this repo (see README for the guides); add them to the buttons.
class SocialButtons extends ConsumerWidget {
  const SocialButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers =
        ref.watch(availableSocialProvidersProvider).value ??
        const <SocialProvider>[];
    if (providers.isEmpty) return const SizedBox.shrink();
    final state = ref.watch(socialLoginControllerProvider);
    final busy = state is SocialLoginBusy;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final buttons = [
      for (final provider in providers)
        ?_button(
          provider.id,
          dark: dark,
          onPressed: busy
              ? null
              : () => ref
                    .read(socialLoginControllerProvider.notifier)
                    .signIn(provider),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SkeletonSpace.md),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SkeletonSpace.sm),
              child: Text('or'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        for (final button in buttons) ...[
          const SizedBox(height: SkeletonSpace.sm),
          button,
        ],
        if (state is SocialLoginFailed) ...[
          const SizedBox(height: SkeletonSpace.sm),
          Text(
            socialFailureText(state.failure),
            key: const ValueKey('social.error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  static Widget? _button(
    String id, {
    required bool dark,
    required VoidCallback? onPressed,
  }) {
    switch (id) {
      case 'apple':
        return SignInWithAppleButton(
          key: const ValueKey('social.button.apple'),
          onPressed: onPressed ?? () {},
          style: dark
              ? SignInWithAppleButtonStyle.white
              : SignInWithAppleButtonStyle.black,
        );
      case 'google':
        // Google's guide: white (dark theme: #131314) with a 1px outline.
        return _BrandButton(
          id: id,
          label: 'Sign in with Google',
          background: dark ? const Color(0xFF131314) : Colors.white,
          foreground: dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
          outline: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
          onPressed: onPressed,
        );
      case 'kakao':
        // Kakao's guide: #FEE500 with 85% black text.
        return _BrandButton(
          id: id,
          label: 'Sign in with Kakao',
          background: const Color(0xFFFEE500),
          foreground: const Color(0xD9000000),
          onPressed: onPressed,
        );
      case 'naver':
        // Naver's guide: #03C75A with white text.
        return _BrandButton(
          id: id,
          label: 'Sign in with Naver',
          background: const Color(0xFF03C75A),
          foreground: Colors.white,
          onPressed: onPressed,
        );
    }
    return null;
  }
}

class _BrandButton extends StatelessWidget {
  const _BrandButton({
    required this.id,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.outline,
  });

  final String id;
  final String label;
  final Color background;
  final Color foreground;
  final Color? outline;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: ValueKey('social.button.$id'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        // Keeps a filled look while disabled, only dimmer.
        disabledBackgroundColor: background.withValues(alpha: 0.5),
        disabledForegroundColor: foreground.withValues(alpha: 0.5),
        minimumSize: const Size.fromHeight(48),
        side: outline == null ? null : BorderSide(color: outline!),
      ),
      child: Text(label),
    );
  }
}
