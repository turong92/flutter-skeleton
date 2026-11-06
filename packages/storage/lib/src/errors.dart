/// One reason a file is refused: before the upload (the app's rules) or by the
/// server's content check (`STORAGE.FILE_REJECTED`).
class StorageIssue {
  const StorageIssue({required this.code, required this.message});

  /// `SIZE_TOO_LARGE`, `UNSUPPORTED_CONTENT_TYPE`, `UNSUPPORTED_EXTENSION`, or
  /// a code the server sent.
  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// The file broke the app's [StorageFileRules]; nothing was sent.
class StorageValidationError implements Exception {
  StorageValidationError(this.issues);

  final List<StorageIssue> issues;

  @override
  String toString() => 'StorageValidationError($issues)';
}

/// The server looked at the uploaded bytes and refused them
/// (`400 STORAGE.FILE_REJECTED`). The stored object is the server's to clean.
class UploadRejectedError implements Exception {
  UploadRejectedError(this.issues);

  final List<StorageIssue> issues;

  @override
  String toString() => 'UploadRejectedError($issues)';
}

/// The upload was cancelled through its `CancelToken`.
class UploadCancelledError implements Exception {
  @override
  String toString() => 'UploadCancelledError';
}

/// The storage answered the PUT with a failure, or could not be reached.
/// [status] is 0 when there was no response. The presigned address carries a
/// signature, so it is never part of this error.
class UploadHttpError implements Exception {
  UploadHttpError(this.status);

  final int status;

  @override
  String toString() => 'UploadHttpError($status)';
}
