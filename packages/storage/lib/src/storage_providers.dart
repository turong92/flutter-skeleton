import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_api.dart';
import 'uploader.dart';

/// The app overrides this with the one `ApiClient` it uses for everything:
/// `storageApiProvider.overrideWith((ref) => StorageApi(ref.watch(apiClientProvider)))`.
final storageApiProvider = Provider<StorageApi>(
  (ref) => throw UnimplementedError(
    'Override storageApiProvider with a StorageApi built on the app\'s ApiClient',
  ),
);

/// An uploader with no limits of its own (the server's stay). An app with its
/// own limits overrides this with `Uploader(api: ..., rules: ...)`.
final uploaderProvider = Provider<Uploader>(
  (ref) => Uploader(api: ref.watch(storageApiProvider)),
);
