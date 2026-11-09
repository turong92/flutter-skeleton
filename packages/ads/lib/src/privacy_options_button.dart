import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_controller.dart';
import 'ads_labels.dart';
import 'ads_sdk.dart';

/// Whether the consent form must be offered again: asked once the consent flow
/// is over (also when ads were refused: that is when a person may change their
/// mind).
final adsPrivacyOptionsRequiredProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  if (ref.watch(adsControllerProvider) == AdsStatus.starting) return false;
  return ref.watch(adsSdkProvider).privacyOptionsRequired();
});

/// The way in to change the ad consent, which Google's consent policy asks for
/// where a form is shown (EEA and the like). Draws nothing elsewhere.
class AdsPrivacyOptionsButton extends ConsumerWidget {
  const AdsPrivacyOptionsButton({super.key, this.labels = const AdsLabels()});

  final AdsLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(adsPrivacyOptionsRequiredProvider).value != true) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          await ref.read(adsSdkProvider).showPrivacyOptionsForm();
        } on Object {
          // the form could not open: nothing to change
        }
        ref.invalidate(adsPrivacyOptionsRequiredProvider);
      },
      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
      label: Text(labels.privacyOptions),
    );
  }
}
