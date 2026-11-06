import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_providers.dart';

/// A language written in its own language, so a person who cannot read the
/// current one still finds theirs.
const nativeLanguageNames = {
  'ko': '한국어',
  'en': 'English',
  'ja': '日本語',
  'zh': '中文',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
};

String languageName(Locale locale) =>
    nativeLanguageNames[locale.languageCode] ?? locale.languageCode;

/// The languages the app supports, each in its own name; a tap picks one and
/// remembers it. A button that shows the current language (not a bare icon).
class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key, this.tooltip = 'Language'});

  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final supported = ref.watch(i18nConfigProvider).supported;
    return PopupMenuButton<Locale>(
      tooltip: tooltip,
      onSelected: (locale) => ref.read(localeProvider.notifier).pick(locale),
      itemBuilder: (context) => [
        for (final locale in supported)
          CheckedPopupMenuItem<Locale>(
            value: locale,
            checked: locale.languageCode == current.languageCode,
            child: Text(languageName(locale)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language),
            const SizedBox(width: 6),
            Text(languageName(current)),
          ],
        ),
      ),
    );
  }
}
