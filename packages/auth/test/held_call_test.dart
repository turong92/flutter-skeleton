import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';
import 'support/test_client.dart';

/// A write the server refuses until [open] is set, behind the two gate
/// interceptors, with a [HeldCalls] standing in for the app's screen.
class _Setup {
  _Setup() {
    adapter = FakeAdapter((options) {
      if (!open) {
        return FakeAdapter.json(403, {
          'code': refusal,
          'title': 'x',
          'status': 403,
        });
      }
      return FakeAdapter.json(200, {
        'value': {'ok': true},
        'meta': {'timestamp': '2026-01-01T00:00:00Z'},
      });
    });
    client = ApiClient(baseUrl: 'http://localhost/api/v1', adapter: adapter);
    client.dio.interceptors
      ..add(LoginIdRequiredInterceptor(dio: client.dio, onRequired: _hold))
      ..add(EmailRequiredInterceptor(dio: client.dio, onRequired: _hold));
  }

  late final FakeAdapter adapter;
  late final ApiClient client;
  final held = HeldCalls();
  bool open = false;
  String refusal = 'ACCOUNT.EMAIL_REQUIRED';

  /// Counts the holds so [untilHeld] can wait for the interceptor to really
  /// reach [HeldCalls.hold]: a release before that has nobody to release.
  int holds = 0;

  Future<bool> _hold() {
    holds++;
    return held.hold();
  }

  Future<void> untilHeld() async {
    while (holds == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<Object?> post() => client.value<Object?>(
    '/boards/general/posts/7/comments',
    method: 'POST',
    headers: {'Idempotency-Key': 'key-1'},
    decode: (json) => json['ok'],
  );
}

void main() {
  for (final refusal in [
    'ACCOUNT.EMAIL_REQUIRED',
    'ACCOUNT.LOGIN_ID_REQUIRED',
  ]) {
    test(
      '$refusal: the refused call is sent again once the gate is done, '
      'with the same Idempotency-Key, and the caller gets that answer',
      () async {
        final s = _Setup()..refusal = refusal;

        final result = s.post();
        await s.untilHeld();
        expect(s.adapter.requests, hasLength(1)); // held, not answered
        s.open = true;
        s.held.release(resend: true);

        expect(await result, true);
        expect(s.adapter.requests, hasLength(2));
        expect(s.adapter.requests.map((r) => r.headers['Idempotency-Key']), [
          'key-1',
          'key-1',
        ]);
      },
    );
  }

  test('"Later" after a refresh and repeat holds the call once, not again '
      'on the outer chain', () async {
    final store = MemoryTokenStore();
    await store.save(
      const TokenPair(accessToken: 'old', refreshToken: 'refresh-1'),
    );
    final adapter = FakeAdapter((options) {
      if (options.path == '/auth/refresh') {
        return FakeAdapter.json(200, tokenResponse('new', 'refresh-2'));
      }
      return options.headers['Authorization'] == 'Bearer old'
          ? apiError(401, 'x')
          : apiError(403, 'ACCOUNT.EMAIL_REQUIRED');
    });
    final client = testAuthClient(store: store, adapter: adapter);
    var holds = 0;
    client.dio.interceptors.add(
      EmailRequiredInterceptor(
        dio: client.dio,
        onRequired: () async {
          holds++;
          return false; // "Later"
        },
      ),
    );

    await expectLater(
      client.value<Object?>(
        '/boards/general/posts/7/comments',
        method: 'POST',
        decode: (json) => json['ok'],
      ),
      throwsA(isA<ApiRequestError>()),
    );
    expect(holds, 1);
  });

  test('ID gate then email gate: leaving the email screen ends the call '
      'without a second email hold', () async {
    var idDone = false;
    final adapter = FakeAdapter(
      (options) => apiError(
        403,
        idDone ? 'ACCOUNT.EMAIL_REQUIRED' : 'ACCOUNT.LOGIN_ID_REQUIRED',
      ),
    );
    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      adapter: adapter,
    );
    var emailHolds = 0;
    client.dio.interceptors
      ..add(
        LoginIdRequiredInterceptor(
          dio: client.dio,
          onRequired: () async {
            idDone = true;
            return true;
          },
        ),
      )
      ..add(
        EmailRequiredInterceptor(
          dio: client.dio,
          onRequired: () async {
            emailHolds++;
            return false;
          },
        ),
      );

    await expectLater(
      client.value<Object?>('/x', method: 'POST', decode: (json) => json['ok']),
      throwsA(isA<ApiRequestError>()),
    );
    expect(emailHolds, 1);
  });

  test('leaving the gate ends the held call with its original 403', () async {
    final s = _Setup();

    final result = s.post();
    await s.untilHeld();
    s.held.release(resend: false);

    await expectLater(
      result,
      throwsA(
        isA<ApiRequestError>().having(
          (e) => e.code,
          'code',
          'ACCOUNT.EMAIL_REQUIRED',
        ),
      ),
    );
    expect(s.adapter.requests, hasLength(1));
  });
}
