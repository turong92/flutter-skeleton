# skeleton_video

Video for the kotlin-skeleton `video` module (and its `video-jdbc`). Same ids and jobs as the web `@skeleton/video` (`videoApi` · `uploadVideo` · `playbackPlan`). Contract: kotlin-skeleton `docs/modules/video.md`. The conversion to HLS is the server's worker, not this package.

| Piece | What it is |
|---|---|
| `VideoApi` | `start` · `presignParts` · `listParts` · `complete` · `get` · `playback` · `remove` (`/videos/*`; `basePath` if the app opened the controller elsewhere) |
| `uploadVideo` | Opens the upload (or takes up a `resume` one), puts the parts three at a time (each tried four times, a fresh address after a failure), completes with the `ETag`s in order |
| `dioPartPut` | The part `PUT` over a plain `Dio` (no app credentials), reading the `ETag`; any failure is `UploadPartError` without the address |
| `videoContentTypeOf` | MP4 or MOV by the picker's type, else by the name's ending; null for anything else |
| `playbackUrls` · `grantExpired` · `afterFailure` | Which playlist to try first (the compat tier when the original is `big`), when the grant ends (30 s before), and what to do when one did not play (renew once, the other tier, give up) |
| `resolveVideoUrl` | The server's playlist paths are roots of the API host: this makes them full addresses |
| `videoApiProvider` | The app overrides it: `videoApiProvider.overrideWith((ref) => VideoApi(ref.watch(apiClientProvider)))` |

## Using it

```dart
final item = await uploadVideo(
  ref.read(videoApiProvider),
  pickedFile, // an XFile
  purpose: 'attachment',
  put: dioPartPut(Dio()), // a Dio of its own: no token of the app
  // The upload is open and no part has gone: tie the video to your record here.
  // A throw stops the upload (the caller's record refused it).
  onStarted: (session) async { remember(session); await attach(session.id); },
  onProgress: (sent) => setState(() => fraction = sent / total),
  // After a failure, give back the remembered session: only the missing parts go.
  resume: remembered,
);
```

Play with the platform player (`video_player`: AVPlayer on iOS, ExoPlayer on Android, both take HLS as it is):

```dart
final grant = await api.playback(id); // 409 VIDEO.NOT_READY until it is playable
final urls = playbackUrls(grant).map((u) => resolveVideoUrl(u, apiBaseUrl));
VideoPlayerController.networkUrl(Uri.parse(urls.first), formatHint: VideoFormat.hls);
```

## What is guaranteed

- The parts go straight to the storage: the app server never sees the file. The signed addresses are never in an error text or a log.
- The app's `Authorization` never reaches the storage host (give `dioPartPut` a `Dio` that has none).
- Resume only asks the storage which parts it has (`GET parts`); a part of the wrong size is sent again; a `404` (the upload was cleared) starts over, and `onStarted` is told of the new session.

## Not here

- Resuming after the app is closed: the caller keeps the `VideoUploadSession` (the web package keeps it in `localStorage`; a phone app that wants this stores it itself).
- The picture of the first scene, the poster swap (`PUT /videos/{id}/poster`), the quality ladder and the animated lane.
- A player widget: the app draws one over `video_player`.
