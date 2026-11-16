import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

Map<String, Object?> variant([Object? alternates]) => {
  'url': 'https://cdn.example.com/d.gif',
  'width': 480,
  'height': 270,
  'contentType': 'image/gif',
  'alternates': ?alternates,
};

void main() {
  test('alternates are read and the mp4 one is the video address', () {
    final v = ImageVariant.fromJson(
      variant([
        {'url': 'https://cdn.example.com/d.webp', 'contentType': 'image/webp'},
        {'url': 'https://cdn.example.com/d.mp4', 'contentType': 'video/mp4'},
      ]),
    );
    expect(v.alternates.map((a) => a.contentType), ['image/webp', 'video/mp4']);
    expect(v.videoUrl, 'https://cdn.example.com/d.mp4');
  });

  test('an alternate without a string url or contentType is skipped alone', () {
    final v = ImageVariant.fromJson(
      variant([
        {'url': 1, 'contentType': 'video/mp4'},
        {'url': 'https://cdn.example.com/x'},
        {'url': 'https://cdn.example.com/d.mp4', 'contentType': 'video/mp4'},
      ]),
    );
    expect(v.alternates, hasLength(1));
    expect(v.videoUrl, 'https://cdn.example.com/d.mp4');
  });

  test(
    'an older answer without alternates, or with a webp only, has no video',
    () {
      expect(ImageVariant.fromJson(variant()).alternates, isEmpty);
      expect(ImageVariant.fromJson(variant()).videoUrl, isNull);
      final webpOnly = ImageVariant.fromJson(
        variant([
          {
            'url': 'https://cdn.example.com/d.webp',
            'contentType': 'image/webp',
          },
        ]),
      );
      expect(webpOnly.videoUrl, isNull);
    },
  );
}
