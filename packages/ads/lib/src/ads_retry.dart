import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long to wait before the next try to load an ad after [attempt] misses
/// in a row (0 = the first miss): 10 s, doubling, at most 5 minutes (the way
/// Google's samples back off). Tests override it.
final adsRetryDelayProvider = Provider<Duration Function(int attempt)>(
  (ref) =>
      (attempt) =>
          Duration(seconds: (10 * (1 << attempt.clamp(0, 5))).clamp(10, 300)),
);
