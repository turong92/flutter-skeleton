import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_legal/skeleton_legal.dart';

ResponseBody forbidden(String code, {Object? data}) => FakeAdapter.json(403, {
  'code': code,
  'title': code,
  'status': 403,
  'timestamp': '2026-01-01T00:00:00Z',
  'data': ?data,
});

const missingJson = {
  'missing': [
    {'type': 'terms', 'version': '2026-12-01', 'reason': 'OUTDATED'},
    {'type': 'privacy', 'version': null, 'reason': 'MISSING'},
  ],
};

void main() {
  group('ReconsentInterceptor on a client that also renews tokens', () {
    late FakeAdapter adapter;
    late MemoryTokenStore store;
    late ApiClient client;
    late List<List<MissingConsent>> required;
    late int sessionsEnded;

    setUp(() async {
      required = [];
      sessionsEnded = 0;
      store = MemoryTokenStore();
      await store.save(
        const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      adapter = FakeAdapter(
        (options) => forbidden('LEGAL.RECONSENT_REQUIRED', data: missingJson),
      );
      client = createAuthClient(
        baseUrl: 'http://x/api/v1',
        tokenStore: store,
        onSessionEnded: () => sessionsEnded++,
        adapter: adapter,
      );
      client.dio.interceptors.add(
        ReconsentInterceptor(onRequired: required.add),
      );
    });

    test('403 LEGAL.RECONSENT_REQUIRED reports what is missing and does not touch the session', () async {
      await expectLater(
        client.value('/notes', decode: (json) => json),
        throwsA(
          isA<ApiRequestError>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.code, 'code', 'LEGAL.RECONSENT_REQUIRED'),
        ),
      );

      expect(required, hasLength(1));
      expect(required.single.map((m) => m.type), ['terms', 'privacy']);
      expect(required.single.first.version, '2026-12-01');
      expect(required.single.last.version, isNull);
      // not a sign-out, not a refresh, the blocked call is not sent again
      expect(sessionsEnded, 0);
      expect(await store.read(), isNotNull);
      expect(adapter.requests.map((r) => r.path), ['/notes']);
    });

    test('any other 403 passes by without a consent state', () async {
      adapter = FakeAdapter((_) => forbidden('COMMON.FORBIDDEN'));
      client.dio.httpClientAdapter = adapter;

      await expectLater(
        client.value('/notes', decode: (json) => json),
        throwsA(
          isA<ApiRequestError>().having(
            (e) => e.code,
            'code',
            'COMMON.FORBIDDEN',
          ),
        ),
      );

      expect(required, isEmpty);
    });
  });

  group('reconsentRedirectFor', () {
    final one = [
      const MissingConsent(type: 'terms', version: '1', reason: 'OUTDATED'),
    ];

    test('nothing missing: stay', () {
      expect(reconsentRedirectFor(const [], Uri.parse('/notes')), isNull);
    });

    test('missing: go to the consent screen and remember where from', () {
      expect(
        reconsentRedirectFor(one, Uri.parse('/board/3?tab=1')),
        '/consent?from=${Uri.encodeQueryComponent('/board/3?tab=1')}',
      );
    });

    test('missing and already on the consent screen: stay', () {
      expect(
        reconsentRedirectFor(one, Uri.parse('/consent?from=%2Fnotes')),
        isNull,
      );
    });

    test('done: leave the consent screen for where the user came from', () {
      expect(
        reconsentRedirectFor(
          const [],
          Uri.parse(
            '/consent?from=${Uri.encodeQueryComponent('/board/3?tab=1')}',
          ),
        ),
        '/board/3?tab=1',
      );
    });

    test('done: a from that is not an app path is ignored', () {
      for (final from in [
        'https://evil.example.com/x',
        '//evil.example.com',
        'board',
      ]) {
        expect(
          reconsentRedirectFor(
            const [],
            Uri.parse('/consent?from=${Uri.encodeQueryComponent(from)}'),
          ),
          '/',
        );
      }
      expect(reconsentRedirectFor(const [], Uri.parse('/consent')), '/');
    });

    test('paths are parameters', () {
      expect(
        reconsentRedirectFor(one, Uri.parse('/a'), consentPath: '/agree'),
        '/agree?from=%2Fa',
      );
      expect(
        reconsentRedirectFor(
          const [],
          Uri.parse('/agree'),
          consentPath: '/agree',
          homePath: '/home',
        ),
        '/home',
      );
    });
  });

  group('reconsentProvider', () {
    test('require stores what is missing, clear forgets it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(reconsentProvider.notifier);

      expect(container.read(reconsentProvider), isEmpty);
      notifier.require(const [
        MissingConsent(type: 'terms', version: '2', reason: 'OUTDATED'),
      ]);
      expect(container.read(reconsentProvider).single.type, 'terms');
      notifier.clear();
      expect(container.read(reconsentProvider), isEmpty);
    });
  });
}
