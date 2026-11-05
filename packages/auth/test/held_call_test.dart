import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

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
      ..add(LoginIdRequiredInterceptor(dio: client.dio, onRequired: held.hold))
      ..add(EmailRequiredInterceptor(dio: client.dio, onRequired: held.hold));
  }

  late final FakeAdapter adapter;
  late final ApiClient client;
  final held = HeldCalls();
  bool open = false;
  String refusal = 'ACCOUNT.EMAIL_REQUIRED';

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
        await Future<void>.delayed(const Duration(milliseconds: 20));
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

  test('leaving the gate ends the held call with its original 403', () async {
    final s = _Setup();

    final result = s.post();
    await Future<void>.delayed(const Duration(milliseconds: 20));
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
