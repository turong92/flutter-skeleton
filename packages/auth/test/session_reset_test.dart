import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

/// Drives the session by hand.
class _Session extends AuthSession {
  @override
  AuthState build() => const SignedOut();

  void set(AuthState next) => state = next;
}

SignedIn _signedIn(String accountId) =>
    SignedIn(Principal(accountId: accountId));

void main() {
  // Counts how many times it was built: a rebuild means it was dropped.
  var built = 0;
  final dataProvider = Provider<int>((ref) => ++built);
  final resetProvider = sessionResetOf({'dataProvider': dataProvider});

  late ProviderContainer container;
  late _Session session;

  setUp(() {
    built = 0;
    container = ProviderContainer(
      overrides: [authSessionProvider.overrideWith(_Session.new)],
    );
    addTearDown(container.dispose);
    container.listen(resetProvider, (_, _) {});
    container.listen(dataProvider, (_, _) {});
    session = container.read(authSessionProvider.notifier) as _Session;
  });

  test('the listed providers are dropped when the session ends', () async {
    session.set(_signedIn('a'));
    await container.pump();
    expect(built, 2, reason: 'dropped when it began, too');

    session.set(const SignedOut());
    await container.pump();

    expect(built, 3);
  });

  test('a switch from one account straight to another drops them', () async {
    session.set(_signedIn('a'));
    await container.pump();
    final before = built;

    session.set(_signedIn('b'));
    await container.pump();

    expect(built, before + 1);
  });

  test('the same account signed in again keeps them', () async {
    session.set(_signedIn('a'));
    await container.pump();
    final before = built;

    session.set(_signedIn('a'));
    await container.pump();

    expect(built, before);
  });
}
