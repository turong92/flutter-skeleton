import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// `ApiError.code` of the push module that this package branches on
/// (kotlin `PushErrorCode`).
abstract final class PushErrorCodes {
  /// 400 on a device PUT: the server has no sender for this kind (FCM off).
  static const kindDisabled = 'PUSH.KIND_DISABLED';

  /// 429 on a test push: one a minute per account.
  static const testTooSoon = 'PUSH.TEST_TOO_SOON';
}

/// The backend calls of the push modules. Stores nothing.
class PushApi {
  PushApi(this._client);

  final ApiClient _client;

  /// `GET /push/config`.
  Future<PushConfig> config() =>
      _client.value('/push/config', decode: PushConfig.fromJson);

  /// `GET /push/preferences`: one switch per pushable kind.
  Future<List<PushPreference>> preferences() async {
    final box = await _client.value(
      '/push/preferences',
      decode: (json) => json,
    );
    return [
      for (final item in box['items']! as List)
        PushPreference.fromJson(item as Map<String, Object?>),
    ];
  }

  /// `PUT /push/preferences/{type}`: only the push channel of that kind.
  Future<PushPreference> setPreference(String type, {required bool enabled}) =>
      _client.value(
        '/push/preferences/$type',
        method: 'PUT',
        json: {'enabled': enabled},
        decode: PushPreference.fromJson,
      );

  /// `PUT /push/devices/{installationId}`: register or refresh this device.
  /// The token is a secret: never log it.
  Future<void> registerDevice(
    String installationId, {
    required String token,
    required String platform,
  }) => _client.value(
    '/push/devices/$installationId',
    method: 'PUT',
    json: {'kind': 'FCM', 'token': token, 'platform': platform},
    decode: (_) {},
  );

  /// `DELETE /push/devices/{installationId}` (204 even when unknown).
  Future<void> removeDevice(String installationId) =>
      _client.noContent('/push/devices/$installationId', method: 'DELETE');

  /// `POST /push/devices/{installationId}/test`: one a minute per account.
  Future<void> sendTest(String installationId) =>
      _client.noContent('/push/devices/$installationId/test', method: 'POST');
}
