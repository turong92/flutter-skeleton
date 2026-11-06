import 'errors.dart';

/// What the app allows before a file is sent. An empty rule is not checked, so
/// the default allows everything: the app decides (the server's own limits stay
/// the real boundary, this only tells the person sooner).
class StorageFileRules {
  const StorageFileRules({
    this.maxSizeBytes,
    this.allowedContentTypes = const [],
    this.allowedExtensions = const [],
  });

  final int? maxSizeBytes;

  /// `image/png` or `image/*`, case ignored.
  final List<String> allowedContentTypes;

  /// `png` or `.png`, case ignored.
  final List<String> allowedExtensions;
}

/// Same meaning and codes as the backend's `StorageFileValidator` and the web
/// `validateFile`. An empty list means the file passes.
List<StorageIssue> validateFile({
  required String fileName,
  required String contentType,
  required int sizeBytes,
  required StorageFileRules rules,
}) {
  final issues = <StorageIssue>[];
  final max = rules.maxSizeBytes;
  if (max != null && sizeBytes > max) {
    issues.add(
      StorageIssue(
        code: 'SIZE_TOO_LARGE',
        message: 'File size $sizeBytes exceeds maximum $max.',
      ),
    );
  }
  if (rules.allowedContentTypes.isNotEmpty &&
      !_contentTypeAllowed(contentType, rules.allowedContentTypes)) {
    issues.add(
      StorageIssue(
        code: 'UNSUPPORTED_CONTENT_TYPE',
        message: "Content type '$contentType' is not allowed.",
      ),
    );
  }
  if (rules.allowedExtensions.isNotEmpty &&
      !_extensionAllowed(fileName, rules.allowedExtensions)) {
    issues.add(
      StorageIssue(
        code: 'UNSUPPORTED_EXTENSION',
        message: "File extension for '$fileName' is not allowed.",
      ),
    );
  }
  return issues;
}

bool _contentTypeAllowed(String contentType, List<String> allowed) {
  final normalized = contentType.toLowerCase().trim();
  if (normalized.isEmpty) return false;
  return allowed.any((entry) {
    final candidate = entry.toLowerCase().trim();
    return candidate == normalized ||
        (candidate.endsWith('/*') &&
            normalized.startsWith(
              candidate.substring(0, candidate.length - 1),
            ));
  });
}

bool _extensionAllowed(String fileName, List<String> allowed) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return false;
  final extension = fileName.substring(dot + 1).toLowerCase().trim();
  if (extension.isEmpty) return false;
  return allowed.any((entry) {
    final candidate = entry.startsWith('.') ? entry.substring(1) : entry;
    return candidate.toLowerCase().trim() == extension;
  });
}
