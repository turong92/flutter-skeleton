import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_app_control/skeleton_app_control.dart';

AppControlConfig config({
  bool maintenance = false,
  String? message,
  String? endsAt,
  Map<String, PlatformPolicy> platforms = const {},
  Map<String, bool> flags = const {},
}) => AppControlConfig(
  serverTime: DateTime.utc(2026, 11, 16, 9),
  maintenance: MaintenanceInfo(
    enabled: maintenance,
    message: message,
    endsAt: endsAt == null ? null : DateTime.parse(endsAt),
  ),
  flags: flags,
  platforms: platforms,
);

Map<String, PlatformPolicy> ios(String? min, String? recommended) => {
  'ios': PlatformPolicy(
    minVersion: min,
    recommendedVersion: recommended,
    storeUrl: 'https://apps.apple.com/app/id1',
  ),
};

void main() {
  test('nothing read yet, or nothing set: the app runs', () {
    expect(appStateOf(null, appVersion: '1.0', platform: 'ios'), isA<AppOk>());
    expect(
      appStateOf(config(), appVersion: '1.0', platform: 'ios'),
      isA<AppOk>(),
    );
  });

  test('maintenance wins over everything, with the message and the end', () {
    final state = appStateOf(
      config(
        maintenance: true,
        message: 'Back at 10',
        endsAt: '2026-11-16T10:00:00Z',
        platforms: ios('9.0', null),
      ),
      appVersion: '1.0',
      platform: 'ios',
    );
    expect(state, isA<AppMaintenance>());
    state as AppMaintenance;
    expect(state.message, 'Back at 10');
    expect(state.endsAt, DateTime.utc(2026, 11, 16, 10));
  });

  test(
    'below the minimum is a required update with the store link, as numbers',
    () {
      final state = appStateOf(
        config(platforms: ios('1.10', null)),
        appVersion: '1.9',
        platform: 'ios',
      );
      expect(state, isA<AppUpdateRequired>());
      expect(
        (state as AppUpdateRequired).storeUrl,
        'https://apps.apple.com/app/id1',
      );
      expect(
        appStateOf(
          config(platforms: ios('1.9', null)),
          appVersion: '1.10',
          platform: 'ios',
        ),
        isA<AppOk>(),
      );
    },
  );

  test('between the minimum and the recommended one it is a recommendation, until dismissed', () {
    final c = config(platforms: ios('1.0', '1.10'));
    expect(
      appStateOf(c, appVersion: '1.9', platform: 'ios'),
      isA<AppUpdateRecommended>(),
    );
    expect(
      appStateOf(c, appVersion: '1.9', platform: 'ios', dismissed: '1.10'),
      isA<AppOk>(),
    );
    // a newer recommended version asks again
    expect(
      appStateOf(
        config(platforms: ios('1.0', '1.11')),
        appVersion: '1.9',
        platform: 'ios',
        dismissed: '1.10',
      ),
      isA<AppUpdateRecommended>(),
    );
  });

  test('a platform the server has no rule for, or a version nobody can read, is never blocked', () {
    final c = config(platforms: ios('9.0', null));
    expect(appStateOf(c, appVersion: '1.0', platform: 'android'), isA<AppOk>());
    expect(appStateOf(c, appVersion: 'dev', platform: 'ios'), isA<AppOk>());
    expect(appStateOf(c, appVersion: null, platform: 'ios'), isA<AppOk>());
  });
}
