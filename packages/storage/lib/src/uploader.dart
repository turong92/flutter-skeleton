import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'errors.dart';
import 'file_rules.dart';
import 'models.dart';
import 'storage_api.dart';
import 'upload_file.dart';

class UploadProgress {
  const UploadProgress({required this.sent, required this.total});

  final int sent;
  final int total;

  /// 0..1; 1 when the size is unknown.
  double get fraction => total > 0 ? sent / total : 1;
}

class UploadResult {
  const UploadResult({required this.key, this.inspection});

  /// The storage key. Give it to the server (a post's `attachments`) to tie the
  /// file to a record.
  final String key;

  /// Only when [Uploader.complete] is on: what the server found in the bytes.
  final UploadInspection? inspection;
}

/// presign, then the file goes straight to the storage with a PUT (progress,
/// cancel), then `complete` so the server checks the bytes. The app server only
/// issues the address; it never sees the file.
class Uploader {
  /// [putClient] is the HTTP client of the PUT. It must carry no credentials of
  /// the app: the presigned address is the credential, and sending the app's
  /// `Authorization` to the storage host would hand it the token. The default
  /// is a plain `Dio`.
  Uploader({
    required this.api,
    Dio? putClient,
    this.rules = const StorageFileRules(),
    this.complete = true,
  }) : _putClient = putClient ?? Dio();

  final StorageApi api;
  final Dio _putClient;

  /// The app's own limits, checked before anything is sent. The default allows
  /// everything.
  final StorageFileRules rules;

  /// Call `complete` after the PUT so the server checks the content and a
  /// refusal comes back as [UploadRejectedError]. Turn it off only for a server
  /// without that endpoint.
  final bool complete;

  Future<UploadResult> upload(
    UploadFile file, {
    void Function(UploadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final size = await file.length();
    final issues = validateFile(
      fileName: file.name,
      contentType: file.contentType,
      sizeBytes: size,
      rules: rules,
    );
    if (issues.isNotEmpty) throw StorageValidationError(issues);

    _throwIfCancelled(cancelToken);
    final presigned = await _refusals(
      () => api.presign(
        StorageCandidate(
          fileName: file.name,
          contentType: file.contentType,
          sizeBytes: size,
        ),
      ),
    );
    _throwIfCancelled(cancelToken);
    await _put(presigned, file, size, onProgress, cancelToken);
    onProgress?.call(UploadProgress(sent: size, total: size));
    _throwIfCancelled(cancelToken);
    if (!complete) return UploadResult(key: presigned.key);
    final inspection = await _inspect(presigned.key);
    _throwIfCancelled(cancelToken);
    return UploadResult(key: presigned.key, inspection: inspection);
  }

  Future<void> _put(
    PresignedUpload presigned,
    UploadFile file,
    int size,
    void Function(UploadProgress)? onProgress,
    CancelToken? cancelToken,
  ) async {
    try {
      await _putClient.request<Object?>(
        presigned.url,
        data: file.openRead(),
        cancelToken: cancelToken,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) => onProgress(
                UploadProgress(sent: sent, total: total > 0 ? total : size),
              ),
        options: Options(
          method: presigned.method,
          headers: {
            ...presigned.headers,
            Headers.contentLengthHeader: size.toString(),
          },
          // the PUT answer has no body worth reading
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw UploadCancelledError();
      // not `e` itself: its message holds the signed address
      throw UploadHttpError(e.response?.statusCode ?? 0);
    }
  }

  Future<UploadInspection> _inspect(String key) =>
      _refusals(() => api.complete(key));

  /// The server refuses a file at presign (its rules) and at complete (the
  /// bytes). Only a `400 STORAGE.FILE_REJECTED` is a refusal; anything else is
  /// thrown as it came.
  Future<T> _refusals<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiRequestError catch (e) {
      if (e.apiError.code == ErrorCodes.storageFileRejected) {
        throw UploadRejectedError(_issuesOf(e.apiError));
      }
      rethrow;
    }
  }

  List<StorageIssue> _issuesOf(ApiError error) {
    final listed = error.data is Map ? (error.data! as Map)['errors'] : null;
    final issues = [
      if (listed is List)
        for (final item in listed)
          if (item is Map && item['code'] is String)
            StorageIssue(
              code: item['code'] as String,
              message: item['message'] as String? ?? item['code'] as String,
            ),
    ];
    return issues.isNotEmpty
        ? issues
        : [StorageIssue(code: 'INSPECTION_REJECTED', message: error.title)];
  }

  void _throwIfCancelled(CancelToken? token) {
    if (token?.isCancelled ?? false) throw UploadCancelledError();
  }
}
