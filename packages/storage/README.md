# skeleton_storage

Photo upload for the kotlin-skeleton `storage` + `storage-s3` modules (and `storage-image` when the server resizes). Same id and same job as the web `@skeleton/storage`. Contract: kotlin-skeleton `docs/modules/storage.md`, `docs/modules/storage-image.md`.

| Piece | What it is |
|---|---|
| `StorageApi` | `presign` · `complete` (`/storage/*`; `basePath` if the app opened the controller elsewhere) |
| `Uploader` | `upload(file, onProgress, cancelToken)`: rules, presign, PUT to the storage, complete → `UploadResult(key, inspection)` |
| `StorageFileRules` / `validateFile` | The app's own limits (size, content types, extensions). Empty by default: no limit |
| `ImageUploadField` | A button that opens the photo library, a tile per photo (preview, progress, reason when refused, remove). `value` is the list of keys |
| `StoredImage` | Draws a stored picture from its address, keeping its place when the size is known |
| `storageApiProvider` · `uploaderProvider` | The app overrides the first; the second is an `Uploader` without rules |

## Wiring

```dart
ProviderScope(overrides: [
  storageApiProvider.overrideWith((ref) => StorageApi(ref.watch(apiClientProvider))),
])
```

An app with its own limits overrides `uploaderProvider` with `Uploader(api: ..., rules: StorageFileRules(maxSizeBytes: ..., allowedContentTypes: ['image/*']))`.

iOS needs `NSPhotoLibraryUsageDescription` in the app's `Info.plist` (and `Info-Debug.plist`) for the library picker. Android needs nothing for the library.

A server whose public base is a path (kotlin `base-url: /files`) gives addresses without a host; pass them through `resolveStoredUrl(url, apiBaseUrl)` before `StoredImage`. That works when the same origin serves both the API and that path (a reverse proxy in production, the react sample dev server locally); the Spring app alone does not serve `/files`. `ImageUploadField.onBusyChanged` tells a form when uploads run, so it can hold its save button.

## What is guaranteed

- The PUT goes through its own plain `Dio`: **no `Authorization`** of the app reaches the storage host. The presigned address is the credential; it is never put in an error or a log.
- `complete` runs by default, so the server reads the stored bytes; a `400 STORAGE.FILE_REJECTED` is `UploadRejectedError` (with the server's reasons). `complete: false` only for a server without that endpoint.
- The app's rules are a convenience to tell the person sooner; the server stays the boundary.
- A cancel (`CancelToken`) ends with `UploadCancelledError`; a failing PUT is `UploadHttpError(status)`.

## Not here

Multipart (big files, video), camera capture, cropping or reordering, guest upload. A key becomes a picture through the record that holds it (a board post's `attachmentUrls` / `attachmentImages`), then `StoredImage(url: ...)`.

## Korean

English is the default. Korean (polite 해요 style) is `ImageUploadLabels.ko()`; the app picks it by the chosen language (see `skeleton_i18n`). `test/ko_labels_test.dart` checks that a Korean set names every field.
