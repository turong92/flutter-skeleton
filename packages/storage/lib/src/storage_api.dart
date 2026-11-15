import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The backend calls of the `storage` module that an upload needs. Stores
/// nothing. The paths are the module's (`/api/v1/storage/*`, the client's
/// base URL carries `/api/v1`); an app that opened the controller elsewhere
/// gives [basePath].
class StorageApi {
  StorageApi(this._client, {String basePath = '/storage'})
    : _base = basePath.replaceFirst(RegExp(r'/+$'), '');

  final ApiClient _client;
  final String _base;

  /// `POST /storage/presign`.
  Future<PresignedUpload> presign(StorageCandidate candidate) => _client.value(
    '$_base/presign',
    method: 'POST',
    json: candidate.toJson(),
    decode: PresignedUpload.fromJson,
  );

  /// `POST /storage/complete`: the server reads the stored bytes. A refusal is
  /// `400 STORAGE.FILE_REJECTED` (an `ApiRequestError`).
  Future<UploadInspection> complete(String key) => _client.value(
    '$_base/complete',
    method: 'POST',
    json: {'key': key},
    decode: UploadInspection.fromJson,
  );

  /// `POST /storage/images` (`storage-image`): the conversion state and the
  /// signed `thumb` and `display` addresses of up to 20 of the caller's own
  /// keys. A key that is not the caller's is left out of the answer.
  Future<List<StoredImageInfo>> images(List<String> keys) => _client.value(
    '$_base/images',
    method: 'POST',
    json: {'keys': keys},
    decode: (json) => [
      for (final item in (json['items'] as List?) ?? const [])
        StoredImageInfo.fromJson(item as Map<String, Object?>),
    ],
  );
}
