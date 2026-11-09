# skeleton_i18n

Which language the app shows, and a menu to change it. Twin of the web `@skeleton/i18n`: the language is the saved pick (kept on this device only), else the first device language the app supports, else Korean. The texts are not here: the app owns its ARB files (`flutter_localizations` + `gen_l10n`), and the packages take their texts as `*Labels` classes (English by default; `auth`, `push`, `notifications`, `board`, `legal` and `storage` also have a Korean set, `XxxLabels.ko()`).

| Piece | What it is |
|---|---|
| `resolveLocale(supported:, fallback:, saved:, device:)` | The rule above, as a pure function |
| `localeProvider` · `LocaleController` | The language now. `pick(locale)` shows it at once and remembers it; `followDevice()` forgets the pick |
| `I18nConfig` · `i18nConfigProvider` | Supported languages (default `ko`, `en`) and the fallback (`ko`) |
| `LocaleStore` · `SharedPreferencesLocaleStore` | Where the pick is kept. `loadSavedLocale(store)` reads it |
| `savedLocaleProvider` | The pick read before the first frame |
| `LanguageMenu` | Each supported language in its own name (`한국어`, `English`); shows the current one |
| `package:skeleton_i18n/testing.dart` | `arbProblems(base, translation)` (same keys, same `{placeholders}`), `readArb(path)`, `MemoryLocaleStore` |

## Wiring

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final saved = await loadSavedLocale(const SharedPreferencesLocaleStore());
  runApp(ProviderScope(
    overrides: [savedLocaleProvider.overrideWithValue(saved)],
    child: const App(),
  ));
}

// in MaterialApp.router:
locale: ref.watch(localeProvider),
supportedLocales: AppLocalizations.supportedLocales,
localizationsDelegates: AppLocalizations.localizationsDelegates,
```

A package's texts come from the app, in the chosen language:

```dart
final ko = Localizations.localeOf(context).languageCode == 'ko';
LoginForm(labels: ko ? const LoginLabels.ko() : const LoginLabels());
```

Test that the two ARB files match, so a new key is never added to one only:

```dart
expect(arbProblems(readArb('lib/l10n/app_ko.arb'), readArb('lib/l10n/app_en.arb')), isEmpty);
```

## Not here

Translating (the ARB files are yours), dates and numbers (`intl` with the chosen locale), the account's server `locale` (the pick stays on the device, like the web twin), following a change of the device language while the app runs.

## Tests

```bash
cd packages/i18n && flutter test
```
