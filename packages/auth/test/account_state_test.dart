import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

void main() {
  group('password policy', () {
    const policy = PasswordPolicy(
      minLength: 8,
      maxBytes: 12,
      requireLetter: true,
      requireDigit: true,
      requireSymbol: false,
      forbidEmailLocalPart: true,
    );

    test(
      'the upper limit counts UTF-8 bytes, the lower limit counts characters',
      () {
        // 8 characters, 15 bytes: long enough, but over the byte limit.
        final tooLong = 'é' * 7 + '1';
        expect(policy.violations(tooLong), contains(PasswordViolation.tooLong));
        expect(
          policy.violations(tooLong),
          isNot(contains(PasswordViolation.tooShort)),
        );
        // 8 ASCII characters are fine.
        expect(policy.violations('abcdefg1'), isEmpty);
        expect(policy.violations('abc1'), [PasswordViolation.tooShort]);
      },
    );

    test('letters, digits and the email local part', () {
      expect(policy.violations('12345678'), [PasswordViolation.needsLetter]);
      expect(policy.violations('abcdefgh'), [PasswordViolation.needsDigit]);
      expect(policy.violations('mynameis1', email: 'myname@example.com'), [
        PasswordViolation.containsEmail,
      ]);
    });
  });

  group('sign-up attempt', () {
    final now = DateTime.utc(2026, 1, 1, 12);

    test('a live attempt comes back after the app was killed', () async {
      final store = MemorySignUpAttemptStore();
      await store.save(
        SignUpAttempt(
          signUpId: 'su_1',
          expiresAt: now.add(const Duration(minutes: 5)),
        ),
      );

      final restored = await restoreSignUpAttempt(store, now: now);

      expect(restored!.signUpId, 'su_1');
    });

    test('an expired attempt is gone and the store is emptied', () async {
      final store = MemorySignUpAttemptStore();
      await store.save(
        SignUpAttempt(
          signUpId: 'su_1',
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      );

      expect(await restoreSignUpAttempt(store, now: now), isNull);
      expect(await store.read(), isNull);
    });

    test('survives the JSON round trip the secure store uses', () {
      final attempt = SignUpAttempt(
        signUpId: 'su_1',
        expiresAt: now,
        resendAvailableAt: now.add(const Duration(minutes: 1)),
      );

      final back = SignUpAttempt.fromJson(attempt.toJson());

      expect(back.signUpId, 'su_1');
      expect(back.expiresAt, now);
      expect(back.resendAvailableAt, now.add(const Duration(minutes: 1)));
    });
  });

  group('session', () {
    late FakeAuthBackend backend;
    late MemoryTokenStore store;
    late ProviderContainer container;

    ProviderContainer make({SignOutHooks? hooks, FakeAdapter? adapter}) {
      final c = ProviderContainer(
        overrides: [
          authConfigProvider.overrideWithValue(
            const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
          ),
          tokenStoreProvider.overrideWithValue(store),
          httpAdapterProvider.overrideWithValue(adapter ?? backend.adapter),
          if (hooks != null) signOutHooksProvider.overrideWithValue(hooks),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      backend = FakeAuthBackend();
      store = MemoryTokenStore();
    });

    Future<void> settle(ProviderContainer c) async {
      c.read(authSessionProvider);
      while (c.read(authSessionProvider) is AuthChecking) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'signInWith stores the tokens and signs in (the code check is the login)',
      () async {
        container = make();
        await settle(container);
        final result = AuthResult(
          tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
          principal: const Principal(accountId: 'acc_new'),
        );

        await container.read(authSessionProvider.notifier).signInWith(result);

        expect(
          container.read(authSessionProvider),
          isA<SignedIn>().having((s) => s.principal.accountId, 'id', 'acc_new'),
        );
        expect((await store.read())!.refreshToken, 'r');
      },
    );

    test('sign-out hooks run before the server is told, and see the tokens still stored', () async {
      await store.save(
        const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      final hooks = SignOutHooks();
      final order = <String>[];
      hooks.add(() async {
        order.add('hook:${(await store.read()) != null}');
      });
      final spy = FakeAdapter((options) {
        order.add(options.path);
        return backend.adapter.fetch(options, null, null);
      });
      container = make(hooks: hooks, adapter: spy);
      await settle(container);

      await container.read(authSessionProvider.notifier).logout();

      expect(order.where((e) => e != '/auth/me'), [
        'hook:true',
        '/auth/logout',
      ]);
    });

    test('a hook that throws or hangs does not stop the sign-out', () async {
      await store.save(
        const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      final hooks = SignOutHooks(timeout: const Duration(milliseconds: 50));
      hooks.add(() async => throw StateError('push backend down'));
      hooks.add(() => Completer<void>().future); // never finishes
      container = make(hooks: hooks);
      await settle(container);

      final previous = FlutterError.onError;
      FlutterError.onError = (_) {}; // the broken hook is reported, not thrown
      addTearDown(() => FlutterError.onError = previous);

      await container.read(authSessionProvider.notifier).logout();

      expect(container.read(authSessionProvider), isA<SignedOut>());
      expect(await store.read(), isNull);
    });

    test('a removed hook is not called again', () async {
      final hooks = SignOutHooks();
      var calls = 0;
      final remove = hooks.add(() async => calls++);
      remove();

      await hooks.run();

      expect(calls, 0);
    });

    test(
      'signOutLocally clears the store and does not call the server',
      () async {
        await store.save(
          const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
        );
        container = make();
        await settle(container);
        backend.requests.clear();

        await container.read(authSessionProvider.notifier).signOutLocally();

        expect(container.read(authSessionProvider), isA<SignedOut>());
        expect(await store.read(), isNull);
        expect(backend.requests, isEmpty);
      },
    );
  });

  group('redirect with public paths', () {
    const principal = Principal(accountId: 'acc_user');
    String? go(AuthState s, String location) => authRedirectFor(
      s,
      location,
      publicPaths: const {
        '/sign-up',
        '/verify',
        '/forgot-password',
        '/reset-password',
      },
    );

    test('signed out may open the account pages, anything else still goes to login', () {
      for (final path in [
        '/sign-up',
        '/verify',
        '/forgot-password',
        '/reset-password',
      ]) {
        expect(go(const SignedOut(), path), isNull, reason: path);
      }
      expect(go(const SignedOut(), '/me'), '/login');
    });

    test(
      'a reset link survives the splash while the session is being checked',
      () {
        expect(go(const AuthChecking(), '/reset-password'), isNull);
        expect(go(const AuthChecking(), '/me'), '/splash');
      },
    );

    test('signed in still leaves login and splash', () {
      expect(go(const SignedIn(principal), '/login'), '/me');
    });
  });
}
