import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'push_api.dart';

const _idKey = 'skeleton_push.installation_id';
const _optOutKey = 'skeleton_push.opted_out';
const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
final _idPattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

/// What this install remembers about push: its installation id (one per
/// install, in `shared_preferences` so a reinstall gets a new one; a Keychain
/// value would survive it) and whether the person turned this device off.
class PushDeviceStore {
  PushDeviceStore({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  Future<String> installationId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_idKey);
    if (stored != null && _idPattern.hasMatch(stored)) return stored;
    final id = List.generate(
      32,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
    await prefs.setString(_idKey, id);
    return id;
  }

  Future<bool> optedOut() async =>
      (await SharedPreferences.getInstance()).getBool(_optOutKey) ?? false;

  Future<void> setOptedOut(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_optOutKey, value);
  }
}

/// Deletes this device's registration. Run it **before** the sign-out, while
/// the tokens are still good (hook it on auth's `signOutHooksProvider`). It
/// never throws and never waits longer than [timeout]: an offline sign-out
/// goes through, at the cost of a registration the server drops later.
Future<void> removeDeviceBeforeSignOut(
  PushApi api,
  PushDeviceStore store, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    final id = await store.installationId();
    await api.removeDevice(id).timeout(timeout);
  } on TimeoutException {
    // gave up waiting
  } on ApiRequestError {
    // offline or refused: the sign-out goes on
  }
}
