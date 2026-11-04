import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

/// Stores the tokens in the iOS Keychain / Android Keystore through
/// `flutter_secure_storage`.
///
/// The iOS Keychain can outlive an uninstall; an app that must not restore a
/// session after a reinstall clears the store on its first launch.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'skeleton_auth.access_token';
  static const _refreshKey = 'skeleton_auth.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<TokenPair?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return TokenPair(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> save(TokenPair tokens) async {
    // Refresh token first: if the app dies between the two writes, the old
    // access token is merely expired and the new refresh token renews it. The
    // other order would keep a spent refresh token.
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    await _storage.write(key: _accessKey, value: tokens.accessToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  @override
  String toString() => 'SecureTokenStore(<redacted>)';
}
