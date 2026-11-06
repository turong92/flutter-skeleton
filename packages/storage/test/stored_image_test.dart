import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

void main() {
  test('a path address is taken from the host of the API', () {
    expect(
      resolveStoredUrl('/files/public/a.jpg', 'https://api.example.com/api/v1'),
      'https://api.example.com/files/public/a.jpg',
    );
  });

  test('a full address stays as it is', () {
    expect(
      resolveStoredUrl(
        'https://cdn.example.com/a.jpg?x=1',
        'https://api.example.com/api/v1',
      ),
      'https://cdn.example.com/a.jpg?x=1',
    );
  });
}
