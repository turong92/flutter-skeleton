@Tags(['backend'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';

// Runs the inbox client against a real kotlin-skeleton `apps/sample`. No device
// needed. Skipped unless the variables are set:
//
//   API_BASE_URL=http://localhost:8080/api/v1 \
//   API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
//   flutter test --tags backend test/backend
final _env = Platform.environment;
final _baseUrl = _env['API_BASE_URL'];
final _email = _env['API_SEED_EMAIL'];
final _password = _env['API_SEED_PASSWORD'];

void main() {
  final skip = _baseUrl == null || _email == null || _password == null
      ? 'Set API_BASE_URL, API_SEED_EMAIL and API_SEED_PASSWORD'
      : null;

  test('the inbox lists, counts unread and marks everything read', () async {
    final login = ApiClient(baseUrl: _baseUrl!);
    final accessToken = await login.value(
      '/auth/login',
      method: 'POST',
      json: {'email': _email, 'password': _password},
      decode: (json) => json['accessToken']! as String,
    );
    final api = NotificationsApi(
      ApiClient(
        baseUrl: _baseUrl!,
        headerProviders: [
          () => {'Authorization': 'Bearer $accessToken'},
        ],
      ),
    );

    final page = await api.list();
    final before = await api.unreadCount();
    await api.markAllRead();
    final after = await api.unreadCount();

    expect(page.pagination.page, 0);
    expect(before, greaterThanOrEqualTo(0));
    expect(after, 0);
    expect((await api.list(unreadOnly: true)).items, isEmpty);
  }, skip: skip);
}
