@Tags(['backend'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_legal/skeleton_legal.dart';

// Runs the legal client against a real kotlin-skeleton `apps/api`. No device
// needed. Skipped unless the variables are set:
//
//   API_BASE_URL=http://localhost:8080/api/v1 \
//   API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
//   flutter test --tags backend test/backend
//
// The seed account is only for the consent status/agree test (see
// packages/auth/README.md for starting the starter with one).
final _env = Platform.environment;
final _baseUrl = _env['API_BASE_URL'];
final _email = _env['API_SEED_EMAIL'];
final _password = _env['API_SEED_PASSWORD'];

void main() {
  final skip = _baseUrl == null
      ? 'Set API_BASE_URL to run against a backend'
      : null;
  final skipSeed =
      skip ??
      (_email == null || _password == null
          ? 'Set API_SEED_EMAIL and API_SEED_PASSWORD'
          : null);

  test('the document list names terms and privacy as sign-up documents, and '
      'a document reads as markdown', () async {
    final api = LegalApi(ApiClient(baseUrl: _baseUrl!));

    final documents = await api.documents();

    final atSignUp = documents
        .where((d) => d.requiredAtSignUp)
        .map((d) => d.type);
    expect(atSignUp, containsAll(['terms', 'privacy']));
    final terms = documents.firstWhere((d) => d.type == 'terms');
    final detail = await api.document(
      'terms',
      version: terms.version,
      locale: terms.locale,
    );
    expect(detail.version, terms.version);
    expect(detail.markdown, isNotEmpty);
  }, skip: skip);

  test(
    'a sign-up without the consents is 400 LEGAL.CONSENT_REQUIRED',
    () async {
      final client = ApiClient(baseUrl: _baseUrl!);
      final stamp = DateTime.now().microsecondsSinceEpoch;

      await expectLater(
        client.noContent(
          '/account/sign-up',
          method: 'POST',
          json: {
            'email': 'legal-$stamp@example.com',
            'password': 'a-long-enough-password-$stamp',
          },
        ),
        throwsA(
          isA<ApiRequestError>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.code, 'code', 'LEGAL.CONSENT_REQUIRED'),
        ),
      );
    },
    skip: skip,
  );

  test(
    'a signed-in caller reads the status and agrees to what is current',
    () async {
      final login = ApiClient(baseUrl: _baseUrl!);
      final accessToken = await login.value(
        '/auth/login',
        method: 'POST',
        json: {'email': _email, 'password': _password},
        decode: (json) => json['accessToken']! as String,
      );
      final api = LegalApi(
        ApiClient(
          baseUrl: _baseUrl!,
          headerProviders: [
            () => {'Authorization': 'Bearer $accessToken'},
          ],
        ),
      );

      final current = {
        for (final d in await api.documents())
          if (d.required) d.type: d,
      }.values;
      final status = await api.agree([
        for (final d in current)
          ConsentClaim(type: d.type, version: d.version, locale: d.locale),
      ], source: 'contract-test');

      expect(status.blocked, isFalse);
      expect(status.missing, isEmpty);
      expect((await api.status()).missing, isEmpty);
    },
    skip: skipSeed,
  );
}
