# skeleton_ui

Design tokens, light and dark `ThemeData`, and the two small views the starter needs. No backend counterpart. Web counterparts: react-skeleton `tokens` · `theme` · `ui` (Flutter's `ThemeData` covers all three, so they are one package here).

| Export | Meaning |
|---|---|
| `SkeletonColors.seed` · `SkeletonSpace` · `SkeletonRadius` · `SkeletonFontSize` | Tokens as Dart constants. Change the values here to restyle. |
| `skeletonLightTheme()` · `skeletonDarkTheme()` | Material 3 themes built from the tokens. `MaterialApp(theme:, darkTheme:)` follows the system setting; there is no stored theme switch. |
| `LoadingView` | Centered spinner. |
| `ErrorView(message:, onRetry:, retryLabel:)` | Centered message and an optional retry button. Texts are parameters (default `Retry`). |

Not here: re-made Material widgets, a theme switch that persists.

```bash
cd packages/ui && flutter test
```
