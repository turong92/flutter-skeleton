import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart' as auth;
import 'package:skeleton_legal/skeleton_legal.dart' as legal;
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import 'form_page.dart';

/// Sign-up with the consent boxes of the `legal` package in the form's slot.
/// A 202 leaves the attempt in the store and goes on to `/verify`.
class SignUpScreen extends ConsumerWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FormPage(
      title: context.l10n.createAccount,
      children: [
        auth.SignUpForm(
          labels: context.byLocale(
            const auth.SignUpLabels.ko(),
            const auth.SignUpLabels(),
          ),
          // The kotlin sample server runs required-on-sign-up: true.
          displayName: auth.DisplayNameMode.required,
          consentBuilder: (context, controller) => legal.SignUpConsents(
            onChanged: (value) => controller.update(
              ready: value.complete,
              // The two packages each have a ConsentClaim; this is the join.
              claims: [
                for (final c in value.claims)
                  auth.ConsentClaim(
                    type: c.type,
                    version: c.version,
                    locale: c.locale,
                  ),
              ],
            ),
          ),
          onConsentRejected: () => ref.invalidate(legal.legalDocumentsProvider),
          onSignedUp: (outcome) =>
              context.go(outcome.attempt == null ? '/login' : '/verify'),
        ),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: Text(context.l10n.alreadyHaveAccount),
        ),
      ],
    );
  }
}
