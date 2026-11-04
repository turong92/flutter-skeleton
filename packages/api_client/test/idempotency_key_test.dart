import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('newIdempotencyKey', () {
    test('has the UUID shape: 8-4-4-4-12 lower-case hex', () {
      expect(
        newIdempotencyKey(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('carries version 4 and the RFC 4122 variant on every key', () {
      for (var i = 0; i < 200; i++) {
        final key = newIdempotencyKey();
        expect(key[14], '4', reason: key);
        expect('89ab', contains(key[19]), reason: key);
      }
    });

    test('differs from call to call', () {
      final keys = {for (var i = 0; i < 200; i++) newIdempotencyKey()};
      expect(keys, hasLength(200));
    });
  });
}
