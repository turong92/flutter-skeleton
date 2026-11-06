import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

ResponseBody _me(Map<String, Object?> extra) => FakeAdapter.json(200, {
  'value': {'hasPassword': true, ...extra},
  'meta': _meta,
});

void main() {
  group('AccountMe', () {
    test('without the avatarKey key the feature is off', () {
      final me = AccountMe.fromJson({'hasPassword': true});
      expect(me.avatarEnabled, isFalse);
      expect(me.avatar, isNull);
    });

    test('a null avatarKey is on with no picture', () {
      final me = AccountMe.fromJson({'hasPassword': true, 'avatarKey': null});
      expect(me.avatarEnabled, isTrue);
      expect(me.avatarKey, isNull);
    });

    test('the converted copy is preferred, then the public address', () {
      final me = AccountMe.fromJson({
        'hasPassword': true,
        'avatarKey': 'u/1/a.png',
        'avatar': {
          'url': 'https://cdn.example.com/a.png',
          'image': {
            'width': 400,
            'height': 400,
            'thumb': 'https://cdn.example.com/a-thumb.webp',
            'display': 'https://cdn.example.com/a.webp',
          },
          'pending': false,
        },
      });
      expect(me.avatar!.thumbUrl, 'https://cdn.example.com/a-thumb.webp');
      expect(
        AccountAvatar.fromJson({'url': 'https://x.example.com/a'}).thumbUrl,
        'https://x.example.com/a',
      );
      expect(AccountAvatar.fromJson({'pending': true}).pending, isTrue);
    });
  });

  group('AccountApi', () {
    AccountApi api(FakeAdapter adapter) => AccountApi(
      ApiClient(baseUrl: 'http://localhost:8080/api/v1', adapter: adapter),
    );

    test('a key sets and null clears: the key is always in the body', () async {
      final adapter = FakeAdapter((_) => _me({'avatarKey': null}));

      await api(adapter).updateAvatar('u/1/a.png');
      await api(adapter).updateAvatar(null);

      expect(adapter.requests.map((r) => r.method), ['PATCH', 'PATCH']);
      expect(adapter.requests[0].data, {'avatarKey': 'u/1/a.png'});
      expect(adapter.requests[1].data, {'avatarKey': null});
    });

    test('avatarAddress reads the signed address', () async {
      final adapter = FakeAdapter(
        (_) => FakeAdapter.json(200, {
          'value': {
            'url': 'https://s.example.com/a?sig=1',
            'expiresInSeconds': 300,
          },
          'meta': _meta,
        }),
      );

      final address = await api(adapter).avatarAddress();

      expect(adapter.requests.single.path, '/account/me/avatar');
      expect(address.expiresInSeconds, 300);
    });
  });

  group('ProfilePictureSection', () {
    late List<RequestOptions> requests;
    ResponseBody Function(RequestOptions) answer = (_) => _me({});

    Future<void> pump(
      WidgetTester tester,
      AccountMe me, {
      void Function(String? key)? pick,
      void Function(bool busy)? busy,
      void Function(AccountMe)? onSaved,
    }) async {
      requests = [];
      final adapter = FakeAdapter((o) {
        requests.add(o);
        return answer(o);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authConfigProvider.overrideWithValue(
              const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
            ),
            tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
            httpAdapterProvider.overrideWithValue(adapter),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProfilePictureSection(
                me: me,
                onSaved: onSaved,
                picker: (context, value, onChanged, onBusy) => Column(
                  children: [
                    Text('value: ${value ?? 'none'}'),
                    TextButton(
                      key: const Key('pick'),
                      onPressed: () => onChanged('u/1/new.png'),
                      child: const Text('pick'),
                    ),
                    TextButton(
                      key: const Key('clear'),
                      onPressed: () => onChanged(null),
                      child: const Text('clear'),
                    ),
                    TextButton(
                      key: const Key('up'),
                      onPressed: () => onBusy(true),
                      onLongPress: () => onBusy(false),
                      child: const Text('up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    AccountMe on({String? key, Map<String, Object?>? avatar}) =>
        AccountMe.fromJson({
          'hasPassword': true,
          'avatarKey': key,
          'avatar': ?avatar,
        });

    testWidgets('a server without storage gets no slot', (tester) async {
      await pump(tester, AccountMe.fromJson({'hasPassword': true}));

      expect(find.text('Profile picture'), findsNothing);
      expect(find.byKey(const Key('pick')), findsNothing);
    });

    testWidgets('saving sends the key the picker gave', (tester) async {
      answer = (_) => _me({'avatarKey': 'u/1/new.png'});
      AccountMe? saved;
      await pump(tester, on(), onSaved: (me) => saved = me);

      await tester.tap(find.byKey(const Key('pick')));
      await tester.pump();
      await tester.tap(find.byKey(ProfilePictureSection.saveKey));
      await tester.pumpAndSettle();

      expect(requests.single.method, 'PATCH');
      expect(requests.single.data, {'avatarKey': 'u/1/new.png'});
      expect(saved?.avatarKey, 'u/1/new.png');
    });

    testWidgets('removing the picture sends null', (tester) async {
      answer = (_) => _me({'avatarKey': null});
      await pump(tester, on(key: 'u/1/old.png'));

      await tester.tap(find.byKey(const Key('clear')));
      await tester.pump();
      await tester.tap(find.byKey(ProfilePictureSection.saveKey));
      await tester.pumpAndSettle();

      expect(requests.single.data, {'avatarKey': null});
    });

    testWidgets('save waits while a photo is going up', (tester) async {
      await pump(tester, on());
      FilledButton save() => tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(ProfilePictureSection.saveKey),
          matching: find.byType(FilledButton),
        ),
      );

      await tester.tap(find.byKey(const Key('up')));
      await tester.pump();
      expect(save().onPressed, isNull);

      await tester.longPress(find.byKey(const Key('up')));
      await tester.pump();
      expect(save().onPressed, isNotNull);
    });

    testWidgets('a refused photo gets its own message', (tester) async {
      answer = (_) => apiError(400, 'COMMON.VALIDATION_FAILED');
      await pump(tester, on());

      await tester.tap(find.byKey(const Key('pick')));
      await tester.pump();
      await tester.tap(find.byKey(ProfilePictureSection.saveKey));
      await tester.pumpAndSettle();

      expect(
        find.text('This photo cannot be used. Please upload a new image file.'),
        findsOneWidget,
      );

      // another photo takes the old refusal away
      await tester.tap(find.byKey(const Key('clear')));
      await tester.pump();
      expect(find.textContaining('cannot be used'), findsNothing);
    });

    testWidgets('a picture still being converted says so', (tester) async {
      await pump(tester, on(key: 'u/1/a.png', avatar: {'pending': true}));

      expect(find.textContaining('being prepared'), findsOneWidget);
    });

    testWidgets('no change saves nothing', (tester) async {
      var saved = 0;
      await pump(tester, on(key: 'u/1/a.png'), onSaved: (_) => saved++);

      await tester.tap(find.byKey(ProfilePictureSection.saveKey));
      await tester.pump();

      expect(requests, isEmpty);
      expect(saved, 1);
    });
  });
}
