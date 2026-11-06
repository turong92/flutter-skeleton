import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// A file to upload: the part of a picked file that the uploader needs, so the
/// uploader does not care where the file came from.
abstract class UploadFile {
  String get name;
  String get contentType;
  Future<int> length();
  Stream<List<int>> openRead();
  Future<Uint8List> readAsBytes();

  /// Wraps a picked file. The content type is the picker's, else guessed from
  /// the extension (`application/octet-stream` when unknown).
  factory UploadFile.fromXFile(XFile file) = _XFileUpload;
}

class _XFileUpload implements UploadFile {
  _XFileUpload(this._file);

  final XFile _file;

  @override
  String get name => _file.name;

  @override
  String get contentType => _file.mimeType ?? guessContentType(_file.name);

  @override
  Future<int> length() => _file.length();

  @override
  Stream<List<int>> openRead() => _file.openRead();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();
}

const _byExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'heif': 'image/heif',
};

/// Content type from a file name's extension.
String guessContentType(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return 'application/octet-stream';
  return _byExtension[fileName.substring(dot + 1).toLowerCase()] ??
      'application/octet-stream';
}
