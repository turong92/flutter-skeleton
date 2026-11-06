import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'errors.dart';
import 'image_upload_labels.dart';
import 'upload_file.dart';
import 'uploader.dart';

/// Gives the photos the person picked; at most [limit] are wanted. Empty when
/// the person backed out.
typedef PhotoSource = Future<List<UploadFile>> Function(int limit);

/// The photo library through `image_picker`. The app needs the platform
/// permission text (iOS `NSPhotoLibraryUsageDescription`).
Future<List<UploadFile>> pickPhotosFromLibrary(int limit) async {
  final picker = ImagePicker();
  if (limit <= 1) {
    final one = await picker.pickImage(source: ImageSource.gallery);
    return [if (one != null) UploadFile.fromXFile(one)];
  }
  final many = await picker.pickMultiImage(limit: limit);
  return [for (final f in many) UploadFile.fromXFile(f)];
}

/// Several photos: a button that opens the library, then one tile per photo
/// with a local preview, progress, the reason when it failed, and a remove
/// button. [value] is the list of storage keys the parent holds (the order
/// shown); a finished upload is added through [onChanged]. Nothing is
/// reordered or cropped.
class ImageUploadField extends StatefulWidget {
  const ImageUploadField({
    super.key,
    required this.uploader,
    required this.value,
    required this.onChanged,
    this.max = 10,
    this.labels = const ImageUploadLabels(),
    this.pickPhotos = pickPhotosFromLibrary,
    this.keyPreview,
    this.onBusyChanged,
  });

  /// True while any upload is running. A form that saves the keys should wait
  /// for false: a save in between leaves the running photo out.
  final ValueChanged<bool>? onBusyChanged;

  final Uploader uploader;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  /// At most this many photos; the button is off at the limit.
  final int max;
  final ImageUploadLabels labels;
  final PhotoSource pickPhotos;

  /// Draws a key that was not uploaded here (a post being edited). Without it
  /// such a tile shows a plain picture icon.
  final Widget Function(BuildContext context, String key)? keyPreview;

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _Upload {
  _Upload(this.id, this.file);

  final int id;
  final UploadFile file;
  final cancel = CancelToken();

  /// Read once: a tile that rebuilds must not read the file again.
  late final Future<Uint8List> bytes = file.readAsBytes();
  double fraction = 0;
  String? problem;
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final _uploads = <_Upload>[];
  final _local = <String, Future<Uint8List>>{};
  late List<String> _latest = widget.value;
  int _nextId = 0;
  bool _busy = false;

  ImageUploadLabels get labels => widget.labels;

  int get _running => _uploads.where((u) => u.problem == null).length;
  bool get _full => widget.value.length + _running >= widget.max;

  @override
  void didUpdateWidget(ImageUploadField old) {
    super.didUpdateWidget(old);
    _latest = widget.value;
  }

  @override
  void dispose() {
    for (final upload in _uploads) {
      upload.cancel.cancel();
    }
    super.dispose();
  }

  Future<void> _add() async {
    final room = widget.max - widget.value.length - _running;
    if (room <= 0) return;
    final files = await widget.pickPhotos(room);
    if (!mounted) return;
    for (final file in files.take(room)) {
      _start(file);
    }
  }

  void _start(UploadFile file) {
    final upload = _Upload(_nextId++, file);
    setState(() => _uploads.add(upload));
    _syncBusy();
    widget.uploader
        .upload(
          file,
          cancelToken: upload.cancel,
          onProgress: (p) {
            if (!mounted) return;
            setState(() => upload.fraction = p.fraction);
          },
        )
        .then<void>((result) {
          if (!mounted) return;
          setState(() {
            _uploads.remove(upload);
            _local[result.key] = upload.bytes;
          });
          _latest = [..._latest, result.key];
          widget.onChanged(_latest);
          _syncBusy();
        })
        .catchError((Object error) {
          if (!mounted || error is UploadCancelledError) return;
          setState(() => upload.problem = _problemOf(error));
          _syncBusy();
        });
  }

  /// Tells the parent when the first upload starts and when the last one ends
  /// (a refused one is over too).
  void _syncBusy() {
    final busy = _running > 0;
    if (busy == _busy) return;
    _busy = busy;
    widget.onBusyChanged?.call(busy);
  }

  String _problemOf(Object error) {
    final issues = switch (error) {
      StorageValidationError(:final issues) => issues,
      UploadRejectedError(:final issues) => issues,
      _ => null,
    };
    if (issues == null) return labels.failed;
    return {for (final i in issues) labels.reasons[i.code] ?? labels.rejected}
        .join(' ');
  }

  void _removeKey(String key) {
    _local.remove(key);
    _latest = [
      for (final k in _latest)
        if (k != key) k,
    ];
    widget.onChanged(_latest);
  }

  void _removeUpload(_Upload upload) {
    upload.cancel.cancel();
    setState(() => _uploads.remove(upload));
    _syncBusy();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('photo-add'),
            onPressed: _full ? null : _add,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(labels.add),
          ),
        ),
        if (widget.value.isNotEmpty || _uploads.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in widget.value)
                  _Tile(
                    key: ValueKey('photo-$key'),
                    bytes: _local[key],
                    fallback: widget.keyPreview?.call(context, key),
                    removeLabel: labels.remove,
                    onRemove: () => _removeKey(key),
                  ),
                for (final upload in _uploads)
                  _Tile(
                    key: ValueKey('photo-upload-${upload.id}'),
                    bytes: upload.bytes,
                    fraction: upload.problem == null ? upload.fraction : null,
                    problem: upload.problem,
                    removeLabel: labels.remove,
                    onRemove: () => _removeUpload(upload),
                  ),
              ],
            ),
          ),
        if (_full)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              labels.limitReached,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.removeLabel,
    required this.onRemove,
    this.bytes,
    this.fallback,
    this.fraction,
    this.problem,
  });

  static const _size = 96.0;

  final Future<Uint8List>? bytes;
  final Widget? fallback;
  final double? fraction;
  final String? problem;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _size,
            height: _size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _preview(scheme),
                ),
                if (fraction != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: LinearProgressIndicator(
                      key: const ValueKey('photo-progress'),
                      value: fraction,
                    ),
                  ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton.filledTonal(
                    key: const ValueKey('photo-remove'),
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    tooltip: removeLabel,
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
          if (problem != null)
            Text(
              problem!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
        ],
      ),
    );
  }

  Widget _preview(ColorScheme scheme) {
    final f = bytes;
    if (f == null) {
      return fallback ??
          ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.image_outlined)),
          );
    }
    return FutureBuilder(
      future: f,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return ColoredBox(color: scheme.surfaceContainerHighest);
        }
        return Image.memory(
          data,
          fit: BoxFit.cover,
          cacheWidth: 256,
          errorBuilder: (context, error, stack) => ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        );
      },
    );
  }
}
