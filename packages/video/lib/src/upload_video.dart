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
/// answered with. Tests put their own in place of [dioPartPut].
typedef PartPut = Future<String> Function(
  PartTarget target,
  Stream<List<int>> body,
  int length,
  void Function(int sent) onProgress,
);

/// A part `PUT` through [dio], which must carry no credentials of the app: the
/// signed address is the credential, and the app's `Authorization` sent to the
/// storage host would hand it the token. Any failure is [UploadPartError]
/// (never the address).
PartPut dioPartPut(Dio dio) => (target, body, length, onProgress) async {
  try {
    final response = await dio.request<Object?>(
      target.url,
      data: body,
      onSendProgress: (sent, _) => onProgress(sent),
      options: Options(
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
  } on DioException {
    // not the exception itself: its message holds the signed address
    throw UploadPartError(target.number);
  }
};

/// Each part is tried this many times: the first and three more.
const _attempts = 4;
const _parallel = 3;
const _partsPerCall = 100;
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
/// that never goes is [UploadPartError].
Future<VideoItem> uploadVideo(
  VideoApi api,
  XFile file, {
  required String purpose,
  VideoVisibility visibility = VideoVisibility.private,
  VideoUploadSession? resume,
  Future<void> Function(VideoUploadSession session)? onStarted,
  void Function(int sent)? onProgress,
  required PartPut put,
  Future<void> Function(Duration wait)? sleep,
}) async {
  final contentType = videoContentTypeOf(file);
  if (contentType == null) throw UnsupportedVideoFileError();
  final wait = sleep ?? (d) => Future<void>.delayed(d);
  final total = await file.length();
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
    );
  }
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
  final targets = <int, PartTarget>{};
  for (var at = 0; at < missing.length; at += _partsPerCall) {
    final slice = missing.sublist(
      at,
      math.min(at + _partsPerCall, missing.length),
    );
    for (final t in await api.presignParts(id, slice)) {
      targets[t.number] = t;
    }
  }

  Future<void> sendPart(int number) async {
    final start = (number - 1) * partSize;
    final length = sizeOf(partSize, number);
    var target = targets[number]!;
    for (var attempt = 1; ; attempt++) {
      try {
        final etag = await put(
          target,
          file.openRead(start, start + length),
          length,
          (sent) {
            sentByPart[number] = math.min(sent, length);
            report();
          },
        );
        sentByPart[number] = length;
        report();
        done[number] = etag;
        return;
      } on UploadPartError {
        if (attempt >= _attempts) rethrow;
        sentByPart[number] = 0;
        await wait(_retryBase * math.pow(2, attempt - 1).toInt());
        // The address may have ended: this part gets a new one.
        final fresh = await api.presignParts(id, [number]);
        if (fresh.isNotEmpty) target = fresh.first;
      }
    }
  }

  final queue = [...missing];
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
