import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The backend call of the `app-control` module. Stores nothing.
class AppControlApi {
  AppControlApi(this._client, {this.basePath = '/app/config'});

  final ApiClient _client;

  /// The server's `skeleton.app-control.config.base-path` after `/api/v1`.
  final String basePath;

  /// `GET /app/config`: maintenance, the switches clients may see and the
  /// version rules per platform. Public and open during maintenance, so no
  /// credentials go with it.
  Future<AppControlConfig> config() => _client.value(
    basePath,
    skipAuth: true,
    decode: AppControlConfig.fromJson,
  );
}
