import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_app_control/skeleton_app_control.dart';

void main() {
  ApiClient clientAnswering(int status, Map<String, Object?> body) => ApiClient(
    baseUrl: 'http://x/api/v1',
    adapter: FakeAdapter((_) => FakeAdapter.json(status, body)),
  );

  const maintenance = {
    'code': 'APP_CONTROL.MAINTENANCE',
    'title': 'Under maintenance',
    'status': 503,
  };

  test('any request that gets the maintenance answer calls back, and still fails as before', () async {
    final client = clientAnswering(503, maintenance);
    var calls = 0;
    installMaintenanceWatch(client, () => calls++);

    await expectLater(
      client.value('/notes', decode: (j) => j),
      throwsA(isA<ApiRequestError>()),
    );

    expect(calls, 1);
  });

  test('another 503, or another failure, does not', () async {
    var calls = 0;
    final other503 = clientAnswering(503, {
      'code': 'COMMON.INTERNAL',
      'title': 'x',
      'status': 503,
    });
    installMaintenanceWatch(other503, () => calls++);
    await expectLater(
      other503.value('/notes', decode: (j) => j),
      throwsA(isA<ApiRequestError>()),
    );
    final notFound = clientAnswering(404, {
      'code': 'COMMON.NOT_FOUND',
      'title': 'x',
      'status': 404,
    });
    installMaintenanceWatch(notFound, () => calls++);
    await expectLater(
      notFound.value('/notes', decode: (j) => j),
      throwsA(isA<ApiRequestError>()),
    );

    expect(calls, 0);
  });

  test(
    'isMaintenanceError reads both the client error and the raw Dio one',
    () {
      expect(
        isMaintenanceError(
          ApiRequestError(
            const ApiError(code: maintenanceErrorCode, title: 'x', status: 503),
          ),
        ),
        isTrue,
      );
      expect(isMaintenanceError(StateError('no')), isFalse);
    },
  );

  test('the platform is exact: ios and android, and a desktop build is not an android', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(container.read(appPlatformProvider), 'ios');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(ProviderContainer().read(appPlatformProvider), 'android');
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(ProviderContainer().read(appPlatformProvider), 'macos');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
