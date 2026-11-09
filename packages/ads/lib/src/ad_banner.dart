import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_controller.dart';
import 'ads_sdk.dart';

/// One anchored adaptive banner. Draws nothing (height 0) until the ads are
/// ready, and when the ad fails to load. [unitId] comes from
/// `AdUnitIds.banner(...)`.
class AdBanner extends ConsumerWidget {
  const AdBanner({super.key, required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(adsRemovedProvider) ||
        ref.watch(adsControllerProvider) != AdsStatus.ready) {
      return const SizedBox.shrink();
    }
    return ref.watch(adsSdkProvider).banner(context, unitId);
  }
}
