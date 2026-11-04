import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'advertising_models.dart';

/// The backend call of `notification-push-legal`. Agreeing and withdrawing go
/// through `skeleton_legal`'s `LegalApi`. Stores nothing.
class AdvertisingApi {
  AdvertisingApi(this._client);

  final ApiClient _client;

  /// `GET /push/advertising`. 404 when the server has no advertising kind.
  Future<Advertising> advertising() =>
      _client.value('/push/advertising', decode: Advertising.fromJson);
}

/// The app overrides this with the `AdvertisingApi` built on its one
/// `ApiClient` (and `legalApiProvider` from `skeleton_legal`).
final advertisingApiProvider = Provider<AdvertisingApi>(
  (ref) => throw UnimplementedError(
    'Override advertisingApiProvider with an AdvertisingApi built on the app\'s ApiClient',
  ),
);
