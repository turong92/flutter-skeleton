import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'form_page.dart';

/// The page a mailed sign-in link opens: `/magic-link?token=...`. The token
/// is only handed to the landing widget, never shown. A sign-in moves the
/// router off this page (its redirect); a dead link offers the sign-in screen.
class MagicLinkScreen extends StatelessWidget {
  const MagicLinkScreen({super.key, required this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Sign in',
      children: [
        MagicLinkLanding(
          token: token,
          onDone: () => context.go('/board'),
          onInvalid: () => context.go('/login'),
        ),
      ],
    );
  }
}
