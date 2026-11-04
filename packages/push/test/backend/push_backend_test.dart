@Tags(['backend'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_push/skeleton_push.dart';

// Runs the push calls against a real kotlin-skeleton `apps/sample` (local
// profile, seed account): config, per-kind switches, and the device PUT, which
// is 200 when the server has an FCM sender (`config.fcm`) and 400
// PUSH.KIND_DISABLED when it has not.
//
//   API_BASE_URL=http://localhost:8080/api/v1 \
//   API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
//   flutter test --tags backend test/backend/push_backend_test.dart
//
// The test removes the device it registers and puts the kind switch back.
final _env = Platform.environment;
final _baseUrl = _env['API_BASE_URL'];

void main() {
  final skip = _baseUrl == null
      ? 'Set API_BASE_URL, API_SEED_EMAIL and API_SEED_PASSWORD to run against a backend'
      : null;

  Future<PushApi> signedIn() async {
    final login = await Dio(BaseOptions(baseUrl: _baseUrl!)).post<Map<String, Object?>>(
      '/auth/login',
      data: {
        'email': _env['API_SEED_EMAIL'] ?? 'user@example.com',
        'password': _env['API_SEED_PASSWORD'] ?? 'password',
      },
    );
    final token = (login.data!['value']! as Map)['accessToken']! as String;
    return PushApi(
      ApiClient(
        baseUrl: _baseUrl!,
        headerProviders: [() => {'Authorization': 'Bearer $token'}],
      ),
    );
  }

  test('config and the per-kind switches', () async {
    final api = await signedIn();

    final config = await api.config();
    final prefs = await api.preferences();

    expect(prefs.map((p) => p.type), config.types);
    if (prefs.isEmpty) return;
    final first = prefs.first;
    final off = await api.setPreference(first.type, enabled: false);
    expect(off.push, isFalse);
    final on = await api.setPreference(first.type, enabled: first.push);
    expect(on.push, first.push);
  }, skip: skip);

  test('the device PUT is 200 with fcm on and 400 KIND_DISABLED without', () async {
    final api = await signedIn();
    final config = await api.config();
    const id = 'flutter-contract-test-0001';

    final register = api.registerDevice(
      id,
      token: 'contract-test-token',
      platform: 'android',
    );

    if (config.fcm) {
      await register;
      await api.removeDevice(id);
    } else {
      await expectLater(
        register,
        throwsA(
          isA<ApiRequestError>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.code, 'code', PushErrorCodes.kindDisabled),
        ),
      );
    }
    await api.removeDevice(id); // 204 even when unknown
  }, skip: skip);
}
