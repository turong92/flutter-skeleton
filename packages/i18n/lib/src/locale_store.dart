import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Where the language the person picked is kept (on this device only; the
/// account's server `locale` is a separate thing).
abstract class LocaleStore {
  /// The saved language code, or null when the person never picked one.
  Future<String?> load();
  Future<void> save(String languageCode);
  Future<void> clear();
}

/// [SharedPreferences], under [key]. A storage that fails does not stop the
/// app: the pick then lasts until the app closes.
class SharedPreferencesLocaleStore implements LocaleStore {
  const SharedPreferencesLocaleStore({this.key = 'skeleton_i18n.locale'});

  final String key;

  @override
  Future<String?> load() async {
    try {
      return (await SharedPreferences.getInstance()).getString(key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(String languageCode) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        key,
        languageCode,
      );
    } on Object {
      // kept in memory by the controller
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } on Object {
      // nothing to do
    }
  }
}

/// The saved pick as a [Locale], or null.
Future<Locale?> loadSavedLocale(LocaleStore store) async {
  final code = await store.load();
  return code == null || code.isEmpty ? null : Locale(code);
}
