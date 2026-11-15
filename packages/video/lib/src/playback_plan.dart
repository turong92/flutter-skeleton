import 'models.dart';

/// Makes a playlist address playable. The server gives a path of its own
/// (`/api/v1/videos/play/...`), taken relative to the host of [apiBaseUrl]; a
/// full address is returned as it is.
String resolveVideoUrl(String url, String apiBaseUrl) {
  final parsed = Uri.parse(url);
  return parsed.hasScheme
      ? url
      : Uri.parse(apiBaseUrl).resolveUri(parsed).toString();
}

/// The playlists to try, in order: the compat tier first when the original is
/// outside what a phone plays well and the compat tier exists, else the
/// original first. A phone's player (AVPlayer, ExoPlayer) takes HLS as it is.
List<String> playbackUrls(VideoPlayback grant) {
  final compat = grant.compat;
  if (compat == null) return [grant.src];
  return grant.big ? [compat, grant.src] : [grant.src, compat];
}

/// The pass in the addresses ends within 30 seconds, or has ended. A public
/// video ([VideoPlayback.expiresAt] null) never does.
bool grantExpired(VideoPlayback grant, DateTime now) {
  final end = grant.expiresAt;
  if (end == null) return false;
  return !end.isAfter(now.add(const Duration(seconds: 30)));
}

enum FailureAction { refresh, next, giveUp }

class FailureDecision {
  const FailureDecision(this.action, [this.url]);

  final FailureAction action;

  /// The playlist to try, for [FailureAction.next].
  final String? url;
}

/// A playlist did not play. When the pass ran out, ask for a new grant (once,
/// [refreshed]); otherwise the tier not tried yet; otherwise give up.
FailureDecision afterFailure({
  required VideoPlayback grant,
  required List<String> tried,
  required DateTime now,
  bool refreshed = false,
}) {
  if (!refreshed && grantExpired(grant, now)) {
    return const FailureDecision(FailureAction.refresh);
  }
  for (final url in playbackUrls(grant)) {
    if (!tried.contains(url)) return FailureDecision(FailureAction.next, url);
  }
  return const FailureDecision(FailureAction.giveUp);
}
