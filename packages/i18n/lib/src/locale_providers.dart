import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_store.dart';
import 'resolve_locale.dart';

/// What the app supports and starts with. The default is Korean and English
/// with Korean as the fallback, the same as the web twin.
class I18nConfig {
  const I18nConfig({
    this.supported = const [Locale('ko'), Locale('en')],
    this.fallback = const Locale('ko'),
  });

  final List<Locale> supported;
  final Locale fallback;
}

final i18nConfigProvider = Provider<I18nConfig>((ref) => const I18nConfig());

final localeStoreProvider = Provider<LocaleStore>(
  (ref) => const SharedPreferencesLocaleStore(),
);

/// The pick read from the store before the first frame:
/// `ProviderScope(overrides: [savedLocaleProvider.overrideWithValue(await loadSavedLocale(store))])`.
/// Null = the person never picked one.
final savedLocaleProvider = Provider<Locale?>((ref) => null);

/// The device's languages, in the order the person prefers them. Tests
/// override it.
final deviceLocalesProvider = Provider<List<Locale>>(
  (ref) => PlatformDispatcher.instance.locales,
);

/// The language the app shows: the saved pick, else the device language the
/// app supports, else the fallback (`ko`). Give it to
/// `MaterialApp.locale`.
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  Locale? _picked;

  @override
  Locale build() {
    final config = ref.watch(i18nConfigProvider);
    _picked ??= ref.read(savedLocaleProvider);
    return resolveLocale(
      supported: config.supported,
      fallback: config.fallback,
      saved: _picked,
      device: ref.watch(deviceLocalesProvider),
    );
  }

  /// The person picked [locale]: shown at once and remembered.
  Future<void> pick(Locale locale) async {
    final config = ref.read(i18nConfigProvider);
    final next = resolveLocale(
      supported: config.supported,
      fallback: config.fallback,
      saved: locale,
    );
    _picked = next;
    state = next;
    await ref.read(localeStoreProvider).save(next.languageCode);
  }

  /// Forget the pick and follow the device again.
  Future<void> followDevice() async {
    _picked = null;
    final config = ref.read(i18nConfigProvider);
    state = resolveLocale(
      supported: config.supported,
      fallback: config.fallback,
      device: ref.read(deviceLocalesProvider),
    );
    await ref.read(localeStoreProvider).clear();
  }
}
