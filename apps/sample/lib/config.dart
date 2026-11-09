/// Build-time settings, passed with `--dart-define-from-file=env/<env>.json`
/// (see `env/dev.json.example`). Nothing is read at run time.
abstract final class AppConfig {
  /// Backend API root including `/api/v1`, e.g. `https://api.example.com/api/v1`.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// The board this app shows (a board code of the sample server).
  static const board = 'general';

  // Firebase, for push. All empty = no Firebase: the app runs and push is
  // reported as unavailable. Take the values from your own Firebase project;
  // never commit them (`env/*.json` is git-ignored).
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  /// The once-bought ad removal (`itemType` / `itemRef` of its row in the
  /// server's product map, `consumable: false`).
  static const adsRemovalItemType = String.fromEnvironment(
    'ADS_REMOVAL_ITEM_TYPE',
    defaultValue: 'ads-removal',
  );
  static const adsRemovalItemRef = String.fromEnvironment(
    'ADS_REMOVAL_ITEM_REF',
    defaultValue: 'ads-removal',
  );

  /// The plan whose running subscription removes the banner and interstitial.
  static const adsRemovalPlanCode = String.fromEnvironment(
    'ADS_REMOVAL_PLAN_CODE',
    defaultValue: 'standard',
  );

  /// The real banner ad units of your AdMob app. Empty = Google's test unit.
  /// Only a release build uses them (see `AdUnitIds`).
  static const adsBannerAndroid = String.fromEnvironment('ADS_BANNER_ANDROID');
  static const adsBannerIos = String.fromEnvironment('ADS_BANNER_IOS');
  static const adsInterstitialAndroid = String.fromEnvironment(
    'ADS_INTERSTITIAL_ANDROID',
  );
  static const adsInterstitialIos = String.fromEnvironment(
    'ADS_INTERSTITIAL_IOS',
  );
  static const adsRewardedAndroid = String.fromEnvironment(
    'ADS_REWARDED_ANDROID',
  );
  static const adsRewardedIos = String.fromEnvironment('ADS_REWARDED_IOS');

  // Social sign-in. An empty value hides that provider's button. The native
  // files read their own copy (`ios/Flutter/Social.xcconfig`,
  // `android/social.properties`); the Kakao key is in both places.
  /// The **web** OAuth client id of the Google Cloud project.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// The iOS OAuth client id; empty = `GIDClientID` of `Info.plist` is used.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );
}
