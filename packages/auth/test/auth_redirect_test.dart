import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

const _principal = Principal(accountId: 'acc_user', roles: ['USER']);

void main() {
  String? redirect(AuthState state, String location) =>
      authRedirectFor(state, location);

  test('while checking, everything goes to the splash route', () {
    expect(redirect(const AuthChecking(), '/me'), '/splash');
    expect(redirect(const AuthChecking(), '/splash'), isNull);
  });

  test('signed out: everything but the login route goes to login', () {
    expect(redirect(const SignedOut(), '/me'), '/login');
    expect(redirect(const SignedOut(), '/splash'), '/login');
    expect(redirect(const SignedOut(), '/login'), isNull);
  });

  test(
    'signed in: login and splash go to the signed-in home, the rest stays',
    () {
      expect(redirect(const SignedIn(_principal), '/login'), '/me');
      expect(redirect(const SignedIn(_principal), '/splash'), '/me');
      expect(redirect(const SignedIn(_principal), '/me'), isNull);
      expect(redirect(const SignedIn(_principal), '/other'), isNull);
    },
  );

  test('the route names can be changed', () {
    expect(
      authRedirectFor(
        const SignedOut(),
        '/home',
        loginPath: '/welcome',
        signedInPath: '/home',
      ),
      '/welcome',
    );
  });
}
