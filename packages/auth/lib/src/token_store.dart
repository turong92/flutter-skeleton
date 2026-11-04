/// An access token with the refresh token that renews it.
///
/// [toString] never prints the values: a pair that lands in a log line, an
/// exception message or a debugger watch must not leak a credential.
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  String toString() => 'TokenPair(<redacted>)';
}

/// Where the tokens live between app starts. Projects differ (secure storage on
/// a device, memory in tests), so the app picks the implementation.
///
/// An implementation must not put token values in its `toString`.
abstract interface class TokenStore {
  Future<TokenPair?> read();
  Future<void> save(TokenPair tokens);
  Future<void> clear();
}

/// Keeps the tokens in memory only. For tests, and for apps that do not want a
/// session to outlive the process.
class MemoryTokenStore implements TokenStore {
  TokenPair? _tokens;

  @override
  Future<TokenPair?> read() async => _tokens;

  @override
  Future<void> save(TokenPair tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;

  @override
  String toString() => 'MemoryTokenStore(<redacted>)';
}
