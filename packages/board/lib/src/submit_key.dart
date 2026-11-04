import 'package:skeleton_api_client/skeleton_api_client.dart';

/// The `Idempotency-Key` of one submit. A retry of the same text (after a
/// network failure) sends the same key, so the server sees one post even if
/// the first request got through. Changed text, or a success, ends the submit:
/// the next one takes a new key.
class SubmitKey {
  String? _key;

  String take() => _key ??= newIdempotencyKey();

  void reset() => _key = null;
}
