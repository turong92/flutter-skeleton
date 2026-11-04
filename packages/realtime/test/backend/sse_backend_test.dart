@Tags(['backend'])
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:skeleton_realtime/skeleton_realtime.dart';
import 'package:test/test.dart';

// Opens the SSE stream on a real kotlin-skeleton `apps/sample` (local profile,
// seed accounts) as the seed user; then the seed admin comments on a post of
// that user and the notification event must arrive. The `connected` greeting
// never reaches onEvent.
//
//   API_BASE_URL=http://localhost:8080/api/v1 \
//   API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
//   API_ADMIN_EMAIL=admin@example.com API_ADMIN_PASSWORD=password \
//   dart test --tags backend test/backend/sse_backend_test.dart
//
// API_BOARD_CODE (default `general`) picks the board. The post is deleted at
// the end.
final _env = Platform.environment;
final _baseUrl = _env['API_BASE_URL'];
final _board = _env['API_BOARD_CODE'] ?? 'general';

void main() {
  final skip = _baseUrl == null
      ? 'Set API_BASE_URL (and the seed accounts) to run against a backend'
      : null;

  Future<Dio> signedIn(String email, String password) async {
    final login = await Dio(BaseOptions(baseUrl: _baseUrl!))
        .post<Map<String, Object?>>(
          '/auth/login',
          data: {'email': email, 'password': password},
        );
    final token = (login.data!['value']! as Map)['accessToken']! as String;
    return Dio(
      BaseOptions(
        baseUrl: _baseUrl!,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<String?> authorId(Dio dio) async {
    final config = await dio.get<Map<String, Object?>>('/boards/config');
    if ((config.data!['value']! as Map)['authorRequired'] != true) return null;
    final profiles = await dio.get<Map<String, Object?>>('/author-profiles');
    return ((profiles.data!['values']! as List).first as Map)['id']! as String;
  }

  test('a comment by the admin reaches the post author as an event', () async {
    final user = await signedIn(
      _env['API_SEED_EMAIL'] ?? 'user@example.com',
      _env['API_SEED_PASSWORD'] ?? 'password',
    );
    final admin = await signedIn(
      _env['API_ADMIN_EMAIL'] ?? 'admin@example.com',
      _env['API_ADMIN_PASSWORD'] ?? 'password',
    );
    final events = Completer<SseEvent>();
    final connection = SseConnection(
      dio: user,
      onEvent: (event) {
        if (!events.isCompleted) events.complete(event);
      },
    )..start();
    addTearDown(connection.close);
    await Future<void>.delayed(const Duration(seconds: 1)); // let it attach

    final created = await user.post<Map<String, Object?>>(
      '/boards/$_board/posts',
      data: {
        'title': 'sse contract ${DateTime.now().microsecondsSinceEpoch}',
        'body': 'for the realtime contract test',
        'authorId': ?await authorId(user),
      },
      options: Options(headers: {'Idempotency-Key': 'sse-${DateTime.now()}'}),
    );
    final postId = (created.data!['value']! as Map)['id'];
    addTearDown(() => user.delete<Object?>('/boards/$_board/posts/$postId'));

    await admin.post<Object?>(
      '/boards/$_board/posts/$postId/comments',
      data: {'body': 'hello', 'authorId': ?await authorId(admin)},
      options: Options(headers: {'Idempotency-Key': 'sse-c-${DateTime.now()}'}),
    );

    final event = await events.future.timeout(const Duration(seconds: 15));
    expect(event.event, isNot('connected'));
    expect(event.data, isNotEmpty);
  }, skip: skip);
}
