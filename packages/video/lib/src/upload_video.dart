import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';
import 'video_api.dart';

/// One part could not be put (network, an ended address, the storage said no).
/// The upload sends that part again; this is what is left after the last try.
class UploadPartError implements Exception {
  UploadPartError(this.part);

  final int part;

  @override
  String toString() => 'UploadPartError($part)';
}

/// The upload was cancelled (the caller's [CancelToken]). What was uploaded
/// stays with the storage; the caller resumes it or calls `VideoApi.remove`.
class UploadCancelled implements Exception {
  @override
  String toString() => 'UploadCancelled';
}

/// The session to resume was opened for a file of another size: nothing was
/// sent. Which file it was is the caller's to keep (a fingerprint of its own);
/// the size is only the check this package can make.
class ResumeFileMismatchError implements Exception {
  @override
  String toString() => 'ResumeFileMismatchError';
}

/// The file is not MP4 or MOV: nothing was sent.
class UnsupportedVideoFileError implements Exception {
  @override
  String toString() => 'UnsupportedVideoFileError';
}

/// The type the server takes, from the picker's type or, without one, the
/// name's ending. Null when it is neither MP4 nor MOV.
String? videoContentTypeOf(XFile file) {
  final type = (file.mimeType ?? '').trim().toLowerCase();
  if (type == 'video/mp4' || type == 'video/quicktime') return type;
  if (type.isNotEmpty) return null;
  final name = file.name.toLowerCase();
  if (name.endsWith('.mp4')) return 'video/mp4';
  if (name.endsWith('.mov')) return 'video/quicktime';
  return null;
}

/// Puts one part (its [length] bytes) and gives the `ETag` the storage
/// answered with. Tests put their own in place of [dioPartPut]. A cancelled
/// [cancelToken] ends it with [UploadCancelled].
typedef PartPut = Future<String> Function(
  PartTarget target,
  Stream<List<int>> body,
  int length,
  void Function(int sent) onProgress, [
  CancelToken? cancelToken,
]);

/// A part `PUT` through [dio], which must carry no credentials of the app: the
/// signed address is the credential, and the app's `Authorization` sent to the
/// storage host would hand it the token. Any failure is [UploadPartError]
/// (never the address), except a cancel, which is [UploadCancelled]. A part
/// that has not been sent in [sendTimeout], or whose answer does not start in
/// 60 seconds, is a failed part (the upload tries it again).
PartPut dioPartPut(
  Dio dio, {
  Duration sendTimeout = const Duration(minutes: 10),
}) => (target, body, length, onProgress, [cancelToken]) async {
  try {
    final response = await dio.request<Object?>(
      target.url,
      data: body,
      cancelToken: cancelToken,
      onSendProgress: (sent, _) => onProgress(sent),
      options: Options(
        sendTimeout: sendTimeout,
        receiveTimeout: const Duration(seconds: 60),
        method: target.method,
        headers: {
          ...target.headers,
          Headers.contentLengthHeader: length.toString(),
        },
        responseType: ResponseType.plain,
      ),
    );
    final etag = response.headers.value('etag');
    if (etag == null || etag.isEmpty) throw UploadPartError(target.number);
    return etag;
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) throw UploadCancelled();
    // not the exception itself: its message holds the signed address
    throw UploadPartError(target.number);
  }
};

/// Each part is tried this many times: the first and three more.
const _attempts = 4;
const _parallel = 3;

/// Addresses are signed for 15 minutes: they are asked for a few parts ahead
/// only, and one older than this is asked for again before its `PUT`.
const _signAhead = 6;
const _addressLife = Duration(minutes: 10);
const _retryBase = Duration(milliseconds: 500);

/// Uploads one video in parts, straight to the storage. Opens the upload (or
/// takes up the [resume] one: the parts the storage holds are kept and only
/// the missing go), puts the parts three at a time (each is tried four times,
/// with a fresh address after a failure) and completes with the `ETag`s in
/// order.
///
/// [onStarted] is awaited once the upload is open and before any part goes:
/// the caller ties the video to its record there (a refusal thrown from it
/// stops the upload). [onProgress] is told the bytes sent so far, which only
/// grow. A refusal of the server is an [ApiRequestError] as it came; a part
/// that never goes is [UploadPartError]. A cancelled [cancelToken] ends it
/// with [UploadCancelled] (checked before every part and every try).
Future<VideoItem> uploadVideo(
  VideoApi api,
  XFile file, {
  required String purpose,
  VideoVisibility visibility = VideoVisibility.private,
  VideoUploadSession? resume,
  Future<void> Function(VideoUploadSession session)? onStarted,
  void Function(int sent)? onProgress,
  required PartPut put,
  CancelToken? cancelToken,
  Future<void> Function(Duration wait)? sleep,
  DateTime Function()? now,
}) async {
  final contentType = videoContentTypeOf(file);
  if (contentType == null) throw UnsupportedVideoFileError();
  final wait = sleep ?? (d) => Future<void>.delayed(d);
  final clock = now ?? DateTime.now;
  void checkCancelled() {
    if (cancelToken?.isCancelled ?? false) throw UploadCancelled();
  }

  checkCancelled();
  final total = await file.length();
  if (resume != null && resume.bytes != total) {
    throw ResumeFileMismatchError();
  }
  int sizeOf(int partSize, int n) =>
      math.min(partSize, total - (n - 1) * partSize);

  var session = resume;
  final done = <int, String>{};
  if (session != null) {
    try {
      for (final part in await api.listParts(session.id)) {
        if (part.bytes == sizeOf(session.partSize, part.n)) {
          done[part.n] = part.etag;
        }
      }
    } on ApiRequestError catch (e) {
      // The server does not know it (it was cleared): from the start. Any
      // other failure (the network) is told as it is.
      if (e.apiError.status != 404) rethrow;
      session = null;
    }
  }
  if (session == null) {
    final started = await api.start(
      bytes: total,
      contentType: contentType,
      purpose: purpose,
      visibility: visibility,
    );
    session = VideoUploadSession(
      id: started.id,
      uploadId: started.uploadId,
      partSize: started.partSize,
      bytes: total,
    );
  }
  checkCancelled();
  await onStarted?.call(session);

  final id = session.id;
  final partSize = session.partSize;
  final numbers = [for (var n = 1; n <= (total / partSize).ceil(); n++) n];
  final sentByPart = <int, int>{
    for (final n in done.keys) n: sizeOf(partSize, n),
  };
  var reported = 0;
  void report() {
    final sum = sentByPart.values.fold<int>(0, (a, b) => a + b);
    reported = math.max(reported, math.min(sum, total));
    onProgress?.call(reported);
  }

  if (done.isNotEmpty) report();

  final missing = [
    for (final n in numbers)
      if (!done.containsKey(n)) n,
  ];
  final queue = [...missing];
  // Asked for together, so a part another worker is waiting on is not asked
  // for twice; a failed ask is forgotten and made again.
  final signed = <int, ({Future<PartTarget> target, DateTime at})>{};
  Future<PartTarget> targetFor(int number) async {
    final held = signed[number];
    if (held == null || clock().difference(held.at) >= _addressLife) {
      final batch = [number, ...queue.take(_signAhead - 1)];
      final at = clock();
      final call = api.presignParts(id, batch);
      for (final n in batch) {
        signed[n] = (
          target: call.then((ts) => ts.firstWhere((t) => t.number == n))
            ..ignore(),
          at: at,
        );
      }
    }
    try {
      return await signed[number]!.target;
    } on Object {
      signed.remove(number);
      rethrow;
    }
  }

  Future<void> sendPart(int number) async {
    final start = (number - 1) * partSize;
    final length = sizeOf(partSize, number);
    var target = await targetFor(number);
    for (var attempt = 1; ; attempt++) {
      checkCancelled();
      try {
        final etag = await put(
          target,
          file.openRead(start, start + length),
          length,
          (sent) {
            sentByPart[number] = math.min(sent, length);
            report();
          },
          cancelToken,
        );
        sentByPart[number] = length;
        report();
        done[number] = etag;
        return;
      } on UploadPartError {
        if (attempt >= _attempts) rethrow;
        sentByPart[number] = 0;
        await wait(_retryBase * math.pow(2, attempt - 1).toInt());
        checkCancelled();
        // The address may have ended: this part gets a new one.
        final fresh = await api.presignParts(id, [number]);
        if (fresh.isNotEmpty) target = fresh.first;
      }
    }
  }

  Object? failure;
  StackTrace? failureTrace;
  Future<void> worker() async {
    while (failure == null && queue.isNotEmpty) {
      try {
        await sendPart(queue.removeAt(0));
      } on Object catch (e, s) {
        failure = e;
        failureTrace = s;
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < math.min(_parallel, missing.length); i++) worker(),
  ]);
  if (failure != null) Error.throwWithStackTrace(failure!, failureTrace!);

  return api.complete(id, [
    for (final n in numbers) CompletedPart(n: n, etag: done[n]!),
  ]);
}
