import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n` for the app's texts, `context.byLocale(ko, en)` for the
/// ready-made Labels sets of the packages (`LoginLabels.ko()` or the English
/// default).
extension AppL10n on BuildContext {
  /// The app's texts in the chosen language. A tree without the delegates (a
  /// widget test that pumps one screen) gets the text of its locale, English
  /// unless that is Korean.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      lookupAppLocalizations(Locale(isKo ? 'ko' : 'en'));

  bool get isKo => Localizations.maybeLocaleOf(this)?.languageCode == 'ko';

  /// [ko] when the app shows Korean, else [en].
  T byLocale<T>(T ko, T en) => isKo ? ko : en;
}
