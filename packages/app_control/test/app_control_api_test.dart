import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_app_control/skeleton_app_control.dart';

void main() {
  test(
    'config reads the public path, sends no credentials and parses the policy',
    () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(200, {
          'value': {
            'serverTime': '2026-11-16T09:00:00Z',
            'maintenance': {
              'enabled': true,
              'message': 'Back at 10',
              'endsAt': '2026-11-16T10:00:00Z',
            },
            'flags': {'beta': true, 'old': false},
            'platforms': {
              'android': {
                'minVersion': '2.0',
                'recommendedVersion': null,
                'storeUrl': 'https://play.google.com/store/apps/details?id=x',
              },
            },
          },
          'meta': {'timestamp': '2026-11-16T09:00:00Z'},
        }),
      );
      final api = AppControlApi(
        ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter),
      );

      final config = await api.config();

      expect(adapter.requests.single.path, '/app/config');
      expect(adapter.requests.single.extra[ApiClient.skipAuthKey], isTrue);
      expect(config.maintenance.enabled, isTrue);
      expect(config.maintenance.endsAt, DateTime.utc(2026, 11, 16, 10));
      expect(config.flags, {'beta': true, 'old': false});
      expect(config.platforms['android']?.minVersion, '2.0');
      expect(config.platforms['android']?.recommendedVersion, isNull);
    },
  );
}
