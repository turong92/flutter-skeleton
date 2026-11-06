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

/// The key comes as a string, or as `{value}` from a Kotlin value class.
String _keyOf(Object? raw) {
  if (raw is String) return raw;
  if (raw is Map && raw['value'] is String) return raw['value']! as String;
  throw const FormatException('storage response has no object key');
}
