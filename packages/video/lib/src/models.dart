/// A video row's main state. `playable` is the moment the original tier is up;
/// the compat tier comes after, on its own.
enum VideoStatus {
  uploading,
  uploaded,
  queued,
  remuxing,
  playable,
  failed,
  deleted;

  /// A state this app does not know is a failure.
  static VideoStatus parse(Object? raw) => values.firstWhere(
    (s) => s.name.toUpperCase() == raw,
    orElse: () => VideoStatus.failed,
  );
}

enum VideoVisibility {
  public('PUBLIC'),
  private('PRIVATE');

  const VideoVisibility(this.wire);

  final String wire;
}

/// `POST /videos`: the upload is open. The parts are [partSize] bytes each
/// (the last one is what is left).
class StartedVideo {
  const StartedVideo({
    required this.id,
    required this.uploadId,
    required this.partSize,
    required this.partCount,
  });

  factory StartedVideo.fromJson(Map<String, Object?> json) => StartedVideo(
    id: json['id']! as String,
    uploadId: json['uploadId']! as String,
    partSize: (json['partSize']! as num).toInt(),
    partCount: (json['partCount']! as num).toInt(),
  );

  final String id;
  final String uploadId;
  final int partSize;
  final int partCount;
}

/// Where to `PUT` one part. The [url] holds a signature: never log it.
class PartTarget {
  const PartTarget({
    required this.number,
    required this.method,
    required this.url,
    required this.headers,
  });

  factory PartTarget.fromJson(Map<String, Object?> json) => PartTarget(
    number: (json['number']! as num).toInt(),
    method: json['method'] as String? ?? 'PUT',
    url: json['url']! as String,
    headers: {
      for (final e in ((json['headers'] as Map?) ?? const {}).entries)
        e.key as String: '${e.value}',
    },
  );

  final int number;
  final String method;
  final String url;
  final Map<String, String> headers;

  @override
  String toString() => 'PartTarget($number)';
}

/// A part the storage already holds (for resuming).
class UploadedPart {
  const UploadedPart({
    required this.n,
    required this.etag,
    required this.bytes,
  });

  factory UploadedPart.fromJson(Map<String, Object?> json) => UploadedPart(
    n: (json['n']! as num).toInt(),
    etag: json['etag']! as String,
    bytes: (json['bytes']! as num).toInt(),
  );

  final int n;
  final String etag;
  final int bytes;
}

class CompletedPart {
  const CompletedPart({required this.n, required this.etag});

  final int n;
  final String etag;

  Map<String, Object?> toJson() => {'n': n, 'etag': etag};
}

/// One video row, with what a screen draws from it.
class VideoItem {
  const VideoItem({
    required this.id,
    required this.status,
    required this.bytes,
    this.progress,
    this.failCode,
    this.durationMs,
  });

  factory VideoItem.fromJson(Map<String, Object?> json) => VideoItem(
    id: json['id']! as String,
    status: VideoStatus.parse(json['status']),
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    progress: (json['progress'] as num?)?.toInt(),
    failCode: json['failCode'] as String?,
    durationMs: (json['durationMs'] as num?)?.toInt(),
  );

  final String id;
  final VideoStatus status;
  final int bytes;

  /// The worker's progress, 0 to 100; null when it is not known.
  final int? progress;
  final String? failCode;

  /// Null before the video is playable.
  final int? durationMs;

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);
}

/// `POST /videos/{id}/playback`: the playlists, as the server made them. They
/// are paths of the API (or full addresses): [resolveVideoUrl] makes them full.
class VideoPlayback {
  const VideoPlayback({
    required this.src,
    required this.poster,
    required this.codec,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.big,
    this.compat,
    this.hls,
    this.expiresAt,
  });

  factory VideoPlayback.fromJson(Map<String, Object?> json) => VideoPlayback(
    src: json['src']! as String,
    compat: json['compat'] as String?,
    hls: json['hls'] as String?,
    poster: json['poster'] as String? ?? '',
    codec: json['codec'] as String? ?? '',
    width: (json['w'] as num?)?.toInt() ?? 0,
    height: (json['h'] as num?)?.toInt() ?? 0,
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    big: json['big'] as bool? ?? false,
    expiresAt: json['expiresAt'] is String
        ? DateTime.parse(json['expiresAt']! as String)
        : null,
  );

  /// The original tier's playlist.
  final String src;

  /// The compat tier's playlist, once it exists.
  final String? compat;

  /// The master playlist, once it exists.
  final String? hls;
  final String poster;
  final String codec;
  final int width;
  final int height;
  final int durationMs;

  /// The original is outside what a phone plays well (4K): the compat tier is
  /// the one to start with.
  final bool big;

  /// When the pass in the addresses ends; null for a public video.
  final DateTime? expiresAt;
}

/// What a resumed upload needs to find its way back: where it was opened, and
/// the size of the file it was opened for (a resume with a file of another
/// size is refused). Which file it was is the caller's to keep.
class VideoUploadSession {
  const VideoUploadSession({
    required this.id,
    required this.uploadId,
    required this.partSize,
    required this.bytes,
  });

  final String id;
  final String uploadId;
  final int partSize;
  final int bytes;
}
