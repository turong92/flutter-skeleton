import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_legal/skeleton_legal.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> summary(
  String type, {
  String locale = 'en',
  String version = '2026-01-01',
  bool requiredAtSignUp = true,
  bool required = true,
  String? title,
}) => {
  'type': type,
  'locale': locale,
  'version': version,
  'effectiveFrom': '2026-01-01T00:00:00Z',
  'title': title ?? type,
  'sha256': 'abc',
  'required': required,
  'requiredAtSignUp': requiredAtSignUp,
  'template': false,
  'next': null,
};

LegalApi apiWith(FakeAdapter adapter) =>
    LegalApi(ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter));

void main() {
  test('documents reads the public list and sends no credentials', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(200, {
        'values': [
          summary('terms'),
          summary('marketing', requiredAtSignUp: false, required: false),
        ],
        'meta': _meta,
      }),
    );

    final documents = await apiWith(adapter).documents();

    expect(adapter.requests.single.path, '/legal/documents');
    expect(adapter.requests.single.extra[ApiClient.skipAuthKey], true);
    expect(documents.map((d) => d.type), ['terms', 'marketing']);
    expect(documents[0].requiredAtSignUp, isTrue);
    expect(documents[1].requiredAtSignUp, isFalse);
    expect(documents[1].required, isFalse);
    expect(documents[0].version, '2026-01-01');
    expect(documents[0].locale, 'en');
  });

  test('document reads one version as markdown', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(200, {
        'value': {
          ...summary('terms', title: 'Terms'),
          'requestedLocale': 'ko',
          'current': true,
          'markdown': '# Terms\n\n**bold**',
        },
        'meta': _meta,
      }),
    );

    final document = await apiWith(adapter)
        .document('terms', version: '2026-01-01', locale: 'ko');

    final request = adapter.requests.single;
    expect(request.path, '/legal/documents/terms');
    expect(request.queryParameters, {'version': '2026-01-01', 'locale': 'ko'});
    expect(document.title, 'Terms');
    expect(document.markdown, '# Terms\n\n**bold**');
  });

  test('agree posts the (type, version, locale) pairs as they are', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(200, {
        'value': {
          'blocked': false,
          'items': <Object?>[],
          'missing': <Object?>[],
        },
        'meta': _meta,
      }),
    );

    final status = await apiWith(adapter).agree(const [
      ConsentClaim(type: 'terms', version: '2026-01-01', locale: 'en'),
      ConsentClaim(type: 'privacy', version: '2026-02-01'),
    ], source: 're-consent');

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/legal/consents');
    expect(request.data, {
      'consents': [
        {'type': 'terms', 'version': '2026-01-01', 'locale': 'en'},
        {'type': 'privacy', 'version': '2026-02-01'},
      ],
      'source': 're-consent',
    });
    expect(status.blocked, isFalse);
    expect(status.missing, isEmpty);
  });

  test('withdraw posts to the type with no body', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(200, {
        'value': {
          'blocked': false,
          'items': <Object?>[],
          'missing': <Object?>[],
        },
        'meta': _meta,
      }),
    );

    final status = await apiWith(adapter).withdraw('marketing-night');

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/legal/consents/marketing-night/withdraw');
    expect(request.data, isNull);
    expect(status.blocked, isFalse);
  });

  test('status lists what is still missing', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(200, {
        'value': {
          'blocked': true,
          'items': <Object?>[],
          'missing': [
            {'type': 'terms', 'version': '2026-12-01', 'reason': 'OUTDATED'},
          ],
        },
        'meta': _meta,
      }),
    );

    final status = await apiWith(adapter).status();

    expect(adapter.requests.single.path, '/legal/consents/me');
    expect(status.blocked, isTrue);
    expect(status.missing.single.type, 'terms');
    expect(status.missing.single.version, '2026-12-01');
  });

  test('an error body reaches the caller as ApiRequestError', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(404, {
        'code': 'LEGAL.DOCUMENT_NOT_FOUND',
        'title': 't',
        'status': 404,
        'timestamp': '2026-01-01T00:00:00Z',
      }),
    );

    await expectLater(
      apiWith(adapter).document('nope'),
      throwsA(
        isA<ApiRequestError>().having(
          (e) => e.code,
          'code',
          'LEGAL.DOCUMENT_NOT_FOUND',
        ),
      ),
    );
  });
}
