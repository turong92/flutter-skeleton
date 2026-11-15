import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The calls of the `video` module that an app needs. Stores nothing; the file
/// bytes never pass through the server. The paths are the module's
/// (`/api/v1/videos`, the client's base URL carries `/api/v1`); an app that
/// opened the controller elsewhere gives [basePath].
class VideoApi {
  VideoApi(this._client, {String basePath = '/videos'})
    : _base = basePath.replaceFirst(RegExp(r'/+$'), '');

  final ApiClient _client;
  final String _base;

  String _video(String id) => '$_base/${Uri.encodeComponent(id)}';

  /// `POST /videos`: opens the upload. The server checks the policy, the quota
  /// and the size here.
  Future<StartedVideo> start({
    required int bytes,
    required String contentType,
    required String purpose,
    VideoVisibility visibility = VideoVisibility.private,
  }) => _client.value(
    _base,
    method: 'POST',
    json: {
      'bytes': bytes,
      'contentType': contentType,
      'purpose': purpose,
      'visibility': visibility.wire,
    },
    decode: StartedVideo.fromJson,
  );

  /// `POST /videos/{id}/parts`: a signed `PUT` address for each number.
  Future<List<PartTarget>> presignParts(String id, List<int> numbers) =>
      _client.list(
        '${_video(id)}/parts',
        method: 'POST',
        json: {'numbers': numbers},
        decode: PartTarget.fromJson,
      );

  /// `GET /videos/{id}/parts`: what the storage holds already. An upload that
  /// is over or was never there is `404` (an [ApiRequestError]).
  Future<List<UploadedPart>> listParts(String id) =>
      _client.list('${_video(id)}/parts', decode: UploadedPart.fromJson);

  /// `POST /videos/{id}/complete`: ends the upload and queues the work. Safe
  /// to send again.
  Future<VideoItem> complete(String id, List<CompletedPart> parts) =>
      _client.value(
        '${_video(id)}/complete',
        method: 'POST',
        json: {
          'parts': [for (final p in parts) p.toJson()],
        },
        decode: VideoItem.fromJson,
      );

  /// `GET /videos/{id}`.
  Future<VideoItem> get(String id) =>
      _client.value(_video(id), decode: VideoItem.fromJson);

  /// `POST /videos/{id}/playback`. `409 VIDEO.NOT_READY` while it is not
  /// playable yet.
  Future<VideoPlayback> playback(String id) => _client.value(
    '${_video(id)}/playback',
    method: 'POST',
    decode: VideoPlayback.fromJson,
  );

  /// `DELETE /videos/{id}`: stops an upload in flight and removes the video.
  Future<void> remove(String id) =>
      _client.noContent(_video(id), method: 'DELETE');
}
