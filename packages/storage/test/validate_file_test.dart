import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

List<String> codes(
  String name,
  String type,
  int size,
  StorageFileRules rules,
) => [
  for (final i in validateFile(
    fileName: name,
    contentType: type,
    sizeBytes: size,
    rules: rules,
  ))
    i.code,
];

void main() {
  test('no rules means no limits', () {
    expect(
      codes('a.bin', 'application/x', 1 << 30, const StorageFileRules()),
      isEmpty,
    );
  });

  test('size, content type wildcard and extension', () {
    const rules = StorageFileRules(
      maxSizeBytes: 100,
      allowedContentTypes: ['IMAGE/*'],
      allowedExtensions: ['.PNG', 'jpg'],
    );

    expect(codes('a.png', 'image/png', 100, rules), isEmpty);
    expect(codes('a.jpg', 'Image/JPEG', 1, rules), isEmpty);
    expect(codes('a.png', 'image/png', 101, rules), ['SIZE_TOO_LARGE']);
    expect(codes('a.png', 'text/plain', 1, rules), [
      'UNSUPPORTED_CONTENT_TYPE',
    ]);
    expect(codes('a.gif', 'image/gif', 1, rules), ['UNSUPPORTED_EXTENSION']);
    expect(codes('png', 'image/png', 1, rules), ['UNSUPPORTED_EXTENSION']);
    expect(codes('a.png', '', 1, rules), ['UNSUPPORTED_CONTENT_TYPE']);
  });
}
