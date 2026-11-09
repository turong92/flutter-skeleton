# skeleton_ads

Google AdMob banner for an app that picks `--packages ads`: consent check (Google's UMP), then the SDK start, then one banner. No backend, no web twin. Test unit ids by default; real ones only in a release build.

| Piece | What it is |
|---|---|
| `adsControllerProvider` | Watch it once at the app root. Each start: consent update, the consent form if one is due, and only when the kept consent allows ad requests, one SDK initialize. State `AdsStatus.starting / ready / unavailable`. A failed update falls back to the consent the SDK kept from before |
| `AdBanner(unitId:)` | An anchored adaptive banner (Google's "large anchored adaptive"). Draws nothing until ready, and when the load fails |
| `AdsPrivacyOptionsButton` | "Change the ad consent". Drawn only where Google's consent policy asks for the entry (EEA and the like); put it in settings or the account screen |
| `AdUnitIds.banner(android:, ios:)` | Picks the platform's unit. Release build and a value: the real unit; anything else (debug, profile, empty): Google's test unit |
| `interstitialAdProvider(unitId)` | Keeps one interstitial loaded once ads are ready. `showIfAllowed()` shows it only when `interstitialMinIntervalProvider` (default 60 s) has passed since the last close, or since the first ad loaded, so none opens right at the start. Never waits: nothing loaded = false. The next one is loaded after each show |
| `rewardedAdProvider((unitId:, ssvUserId:))` | Keeps one rewarded ad loaded; state `RewardedStatus.loading / ready / unavailable`. Turn the "watch an ad" button on only when `ready`. `.notifier.show()` gives an `AdReward?`: the reward only if the SDK said it was earned, null if closed early. `ssvUserId` (the account id) travels to Google's server-side verification |
| `AdsLabels` / `AdsLabels.ko()` | The one text of the button |
| `AdsSdk` (`adsSdkProvider`) | The boundary over the SDK. `FakeAdsSdk` in `package:skeleton_ads/testing.dart` for widget tests (platform-view ads do not run in `flutter test`) |

## Wiring

```dart
// root widget
ref.watch(adsControllerProvider);

// where the banner goes
AdBanner(unitId: AdUnitIds.banner(android: AppConfig.adsBannerAndroid, ios: AppConfig.adsBannerIos))

// settings
AdsPrivacyOptionsButton(labels: context.byLocale(const AdsLabels.ko(), const AdsLabels()))
```

In tests: `adsSdkProvider.overrideWithValue(FakeAdsSdk())`.

The unit ids come from `env/*.json` (`ADS_BANNER_ANDROID`, `ADS_BANNER_IOS`) through `AppConfig`.

## Interstitial and rewarded

```dart
// where a natural break comes (leaving a detail page, a level ends)
await ref.read(interstitialAdProvider(AdUnitIds.interstitial(android: ..., ios: ...))).showIfAllowed();

// a button the person chooses to press
final key = (unitId: AdUnitIds.rewarded(android: ..., ios: ...), ssvUserId: accountId);
final ready = ref.watch(rewardedAdProvider(key)) == RewardedStatus.ready;
final reward = await ref.read(rewardedAdProvider(key).notifier).show();
```

- **A server balance is credited by Google's server-side verification (SSV) only.** Do not build an API that the app calls with "I earned it": anyone can call it. Set the callback address in the AdMob console on the rewarded unit; the receiving side is the kotlin-skeleton `ads-admob` module (`GET /api/v1/ads/admob/ssv`), which credits the points and ignores a repeated `transaction_id`. Test units do not send the callback, so you cannot see points arrive from a test ad; use the console's callback test tool against a deployed server.
- Where an interstitial must not be: at app start or exit, before content has shown, after every action. The minimum interval holds the start and the repeat back, but picking the place is yours. Set a frequency cap on the unit in the AdMob console too.
- A rewarded ad is shown only because the person pressed a button that says what they get.
- Not in the starter on purpose (where to place them is the product's choice); `apps/sample` shows one of each.

## The app id (native files)

The SDK reads the app id from the native files and stops the app at start without it. The stamp leaves Google's **test** app ids; replace them with the real ones from the AdMob console:

- Android `android/app/src/main/AndroidManifest.xml`: `com.google.android.gms.ads.APPLICATION_ID`
- iOS `ios/Runner/Info.plist` and `Info-Debug.plist`: `GADApplicationIdentifier` (and keep `SKAdNetworkItems`)

The app id is public (it ships in the APK/IPA), so it is a plain line in the file, not a git-ignored value file.

## Release checklist

- Real app ids in the three native files above.
- Real banner unit ids in `env/prod.json`.
- AdMob console, Privacy & messaging: a GDPR message (EEA, UK, Switzerland) and, for iOS, an **IDFA explanation message**. **The iOS plist carries `NSUserTrackingUsageDescription`; without the IDFA message in the console the tracking request never shows and App Review can reject it.**
- `app-ads.txt` on the developer website.
- Google Play: declare "Contains ads" and the data safety form (the advertising id).
- To see real ads in a debug build, register the phone as a test device in the AdMob console. Do not put the real unit in a debug build.

## Not here

App-open, native and rewarded-interstitial ads, mediation, the SDK's preloader, a daily reward cap, an "remove ads" purchase, child-directed settings (set `RequestConfiguration` yourself if the app needs them), test-device helpers, frequency caps, the Korean wording of the tracking prompt.

## Not checked on a device

Android SDK and Xcode were not at hand when this was written. Not seen yet: a real banner, the consent form and the privacy form (`DebugGeography.debugGeographyEea`), the iOS tracking prompt. The tests cover the flow through `FakeAdsSdk` only.

Also to look at on a device: on iOS the reward callback may arrive after the ad is closed, so the app's own "you got it" message might not show; a server credit through SSV is separate and not affected.

Known limit: if the first start is offline, consent cannot be read, so ads stay off for that run (no retry until the app starts again).
