import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'video_api.dart';

/// The app overrides this with the one `ApiClient` it uses for everything:
/// `videoApiProvider.overrideWith((ref) => VideoApi(ref.watch(apiClientProvider)))`.
final videoApiProvider = Provider<VideoApi>(
  (ref) => throw UnimplementedError(
    'Override videoApiProvider with a VideoApi built on the app\'s ApiClient',
  ),
);
