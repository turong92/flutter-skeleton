import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

void main() {
  test(
    'images asks for the keys and reads status and signed variants',
    () async {
      final adapter = FakeAdapter((o) async {
        expect(o.path, '/storage/images');
        expect(o.method, 'POST');
        return FakeAdapter.json(200, {
          'value': {
            'items': [
              {
                'key': 'k/1',
                'status': 'READY',
                'width': 2048,
                'height': 1536,
                'variants': {
                  'thumb': {
                    'url': 'https://cdn.example.com/t?sig=secret',
                    'width': 400,
                    'height': 300,
                    'contentType': 'image/webp',
                  },
                  'display': {
                    'url': 'https://cdn.example.com/d?sig=secret',
                    'width': 1600,
                    'height': 1200,
                    'contentType': 'image/webp',
                  },
                },
              },
              {'key': 'k/2', 'status': 'PENDING'},
            ],
          },
          'meta': {'timestamp': '2026-01-01T00:00:00Z'},
        });
      });
      final api = StorageApi(
        ApiClient(baseUrl: 'https://api.example.com/api/v1', adapter: adapter),
      );

      final items = await api.images(['k/1', 'k/2']);

      expect(adapter.requests.single.data, {
        'keys': ['k/1', 'k/2'],
      });
      expect(items.map((i) => (i.key, i.status)), [
        ('k/1', ImageStatus.ready),
        ('k/2', ImageStatus.pending),
      ]);
      final ready = items.first;
      expect((ready.width, ready.height), (2048, 1536));
      expect(ready.thumb!.url, contains('/t?'));
      expect((ready.display!.width, ready.display!.height), (1600, 1200));
      // A pending image has no variants yet.
      expect(items.last.thumb, isNull);
      expect(items.last.display, isNull);
      // The signed address is not in the text of the model.
      expect(ready.thumb.toString(), isNot(contains('secret')));
    },
  );
}
