import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account_models.dart';

/// Where a pending sign-up lives between app starts. Cleared when the code is
/// confirmed or the attempt expired.
abstract interface class SignUpAttemptStore {
  Future<SignUpAttempt?> read();
  Future<void> save(SignUpAttempt attempt);
  Future<void> clear();
}

/// For tests, and for apps that do not want the code screen to survive a kill.
class MemorySignUpAttemptStore implements SignUpAttemptStore {
  SignUpAttempt? _attempt;

  @override
  Future<SignUpAttempt?> read() async => _attempt;

  @override
  Future<void> save(SignUpAttempt attempt) async => _attempt = attempt;

  @override
  Future<void> clear() async => _attempt = null;
}

/// Keychain / Keystore backed.
class SecureSignUpAttemptStore implements SignUpAttemptStore {
  SecureSignUpAttemptStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'skeleton_auth.sign_up_attempt';
  final FlutterSecureStorage _storage;

  @override
  Future<SignUpAttempt?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return SignUpAttempt.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      await _storage.delete(key: _key);
      return null;
    }
  }

  @override
  Future<void> save(SignUpAttempt attempt) =>
      _storage.write(key: _key, value: attempt.encode());

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// The attempt to continue, or null: an expired attempt is removed on the way.
Future<SignUpAttempt?> restoreSignUpAttempt(
  SignUpAttemptStore store, {
  DateTime? now,
}) async {
  final attempt = await store.read();
  if (attempt == null) return null;
  if (!attempt.expiresAt.isAfter(now ?? DateTime.now())) {
    await store.clear();
    return null;
  }
  return attempt;
}
