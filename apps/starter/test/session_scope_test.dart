import 'dart:io';

// #if social-login-apple
import 'package:flutter_riverpod/flutter_riverpod.dart';
// #endif
import 'package:flutter_test/flutter_test.dart';
// #if social-login-apple
import 'package:skeleton_auth/skeleton_auth.dart';
// #endif
import 'package:starter/session_scope.dart';
// #if social-login-apple
import 'package:starter/social_support.dart';

// #endif

/// The top-level providers a Dart source declares, public and private:
/// `final x = FutureProvider...`, `final FutureProvider<T> x = ...`, whatever
/// the name ends with. Private ones that are `.autoDispose` are left out: no
/// screen holds them once the session ends and its screens are gone; a
/// private one that stays alive can only be exempt (another file cannot list
/// it, so it must say why it holds no one's data).
Set<String> declaredProviders(String source) {
  final pattern = RegExp(
    r'^final\s+(?:[\w<>?,. ]+?\s+)?(_?\w+)\s*=\s*(\w*Provider)((?:\.\w+)*)',
    multiLine: true,
  );
  return {
    for (final m in pattern.allMatches(source))
      if (!(m.group(1)!.startsWith('_') && m.group(3)!.contains('autoDispose')))
        m.group(1)!,
  };
}

// #if social-login-apple
/// Drives the session by hand.
class _Session extends AuthSession {
  @override
  AuthState build() => const SignedOut();

  void set(AuthState next) => state = next;
}

// #endif
void main() {
  test('every provider in lib/ is dropped with the session or exempt '
      '(add one to neither list and this fails)', () {
    final declared = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      // The lists themselves, and the reset provider built from them.
      if (file.path.endsWith('session_scope.dart')) continue;
      declared.addAll(declaredProviders(file.readAsStringSync()));
    }
    expect(declared, isNotEmpty);
    final classified = {
      ...userScopedProviders.keys,
      ...sessionScopeExempt.keys,
    };
    expect(declared.difference(classified), isEmpty);
    // An exemption is a name only (it cannot be compiled), so one left behind
    // by a deleted provider is found here. The list of user data is real
    // references and may name providers of a package.
    expect(sessionScopeExempt.keys.toSet().difference(declared), isEmpty);
  });

  // #if social-login-apple
  test("one account's Apple code is not left for the next account", () async {
    final container = ProviderContainer(
      overrides: [authSessionProvider.overrideWith(_Session.new)],
    );
    addTearDown(container.dispose);
    container.listen(sessionResetProvider, (_, _) {});
    container.listen(appleRevokeCodeProvider, (_, _) {});
    final session = container.read(authSessionProvider.notifier) as _Session;
    session.set(const SignedIn(Principal(accountId: 'a')));
    await container.pump();
    container.read(appleRevokeCodeProvider).code = 'a-code';

    // A signs out without deleting; B signs in.
    session.set(const SignedOut());
    await container.pump();
    session.set(const SignedIn(Principal(accountId: 'b')));
    await container.pump();

    expect(container.read(appleRevokeCodeProvider).code, isNull);
  });

  // #endif
  test('an exemption always gives its reason', () {
    for (final entry in sessionScopeExempt.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('the scan sees the declarations a plain pattern would miss', () {
    expect(
      declaredProviders('''
final FutureProvider<int?> typedFirst =
    FutureProvider<int?>((ref) async => 1);
final cart = NotifierProvider<Cart, int>(Cart.new);
final _kept = Provider<int>((ref) => 1);
final _gone = FutureProvider.autoDispose<int>((ref) async => 1);
final publicGone = FutureProvider.autoDispose<int>((ref) async => 1);
final notAProvider = GlobalKey<ScaffoldMessengerState>();
final list = <Override>[];
'''),
      {'typedFirst', 'cart', '_kept', 'publicGone'},
    );
  });
}
