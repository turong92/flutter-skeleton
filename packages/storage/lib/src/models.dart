/// What the server needs to know to issue an upload address. The object key is
/// the server's to choose.
class StorageCandidate {
  const StorageCandidate({
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String fileName;
  final String contentType;
  final int sizeBytes;

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'contentType': contentType,
    'sizeBytes': sizeBytes,
  };
}

/// `POST /storage/presign`: where to PUT, with which headers. The [url] holds a
/// signature: never log it.
class PresignedUpload {
  const PresignedUpload({
    required this.key,
    required this.method,
    required this.url,
    required this.headers,
  });

  factory PresignedUpload.fromJson(Map<String, Object?> json) =>
      PresignedUpload(
        key: _keyOf(json['key']),
        method: json['method'] as String? ?? 'PUT',
        url: json['url']! as String,
        headers: {
          for (final e in ((json['headers'] as Map?) ?? const {}).entries)
            e.key as String: '${e.value}',
        },
      );

  final String key;
  final String method;
  final String url;
  final Map<String, String> headers;

  @override
  String toString() => 'PresignedUpload($key)';
}

/// The server's image state: `pending` (still converting), `ready`, `rejected`,
/// `unsupported` (no preview for this format) or `failed`.
enum ImageStatus {
  pending,
  ready,
  rejected,
  unsupported,
  failed;

  static ImageStatus parse(Object? raw) => values.firstWhere(
    (s) => s.name.toUpperCase() == raw,
    orElse: () => ImageStatus.failed,
  );
}

class ImageInspection {
  const ImageInspection({required this.status, this.width, this.height});

  factory ImageInspection.fromJson(Map<String, Object?> json) =>
      ImageInspection(
        status: ImageStatus.parse(json['status']),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
      );

  final ImageStatus status;
  final int? width;
  final int? height;
}

/// `POST /storage/complete`: what the server found in the uploaded bytes.
/// [image] is null for a file that is not an image, or when the server has no
/// image module.
class UploadInspection {
  const UploadInspection({
    required this.key,
    this.contentType,
    required this.sizeBytes,
    this.image,
  });

  factory UploadInspection.fromJson(Map<String, Object?> json) {
    final image = json['image'];
    return UploadInspection(
      key: _keyOf(json['key']),
      contentType: json['contentType'] as String?,
      sizeBytes: (json['sizeBytes']! as num).toInt(),
      image: image is Map<String, Object?>
          ? ImageInspection.fromJson(image)
          : null,
    );
  }

  final String key;
  final String? contentType;
  final int sizeBytes;
  final ImageInspection? image;
}

/// Another form of the same variant (the server's conversion of an animated
/// image): `video/mp4` (a silent loop) or, for a transparent one, `image/webp`.
class ImageAlternate {
  const ImageAlternate({required this.url, required this.contentType});

  factory ImageAlternate.fromJson(Map<String, Object?> json) => ImageAlternate(
    url: json['url']! as String,
    contentType: json['contentType']! as String,
  );

  final String url;
  final String contentType;
}

/// One converted size of a stored image (`thumb` or `display`). The [url] is a
/// signed address that ends in minutes: never log it.
class ImageVariant {
  const ImageVariant({
    required this.url,
    required this.width,
    required this.height,
    this.contentType,
    this.alternates = const [],
  });

  factory ImageVariant.fromJson(Map<String, Object?> json) => ImageVariant(
    url: json['url']! as String,
    width: (json['width']! as num).toInt(),
    height: (json['height']! as num).toInt(),
    contentType: json['contentType'] as String?,
    alternates: [
      for (final raw in (json['alternates'] as List?) ?? const [])
        if (raw is Map<String, Object?> &&
            raw['url'] is String &&
            raw['contentType'] is String)
          ImageAlternate.fromJson(raw),
    ],
  );

  final String url;
  final int width;
  final int height;
  final String? contentType;

  /// Empty for an older answer, or while the conversion has not run.
  final List<ImageAlternate> alternates;

  /// The silent looping video of an animated image, if the server made one.
  /// This is the one place that decides what is a video.
  String? get videoUrl {
    for (final a in alternates) {
      if (a.contentType == 'video/mp4') return a.url;
    }
    return null;
  }

  @override
  String toString() => 'ImageVariant(${width}x$height)';
}

/// `POST /storage/images`: the state of a stored image and, once it is
/// [ImageStatus.ready], its signed variants.
class StoredImageInfo {
  const StoredImageInfo({
    required this.key,
    required this.status,
    this.width,
    this.height,
    this.thumb,
    this.display,
  });

  factory StoredImageInfo.fromJson(Map<String, Object?> json) {
    final variants = json['variants'];
    ImageVariant? variant(String name) {
      final raw = variants is Map ? variants[name] : null;
      return raw is Map<String, Object?> ? ImageVariant.fromJson(raw) : null;
    }

    return StoredImageInfo(
      key: _keyOf(json['key']),
      status: ImageStatus.parse(json['status']),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      thumb: variant('thumb'),
      display: variant('display'),
    );
  }

  final String key;
  final ImageStatus status;
  final int? width;
  final int? height;
  final ImageVariant? thumb;
  final ImageVariant? display;
}

/// The key comes as a string, or as `{value}` from a Kotlin value class.
String _keyOf(Object? raw) {
  if (raw is String) return raw;
  if (raw is Map && raw['value'] is String) return raw['value']! as String;
  throw const FormatException('storage response has no object key');
}
