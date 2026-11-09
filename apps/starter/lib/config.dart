/// Build-time settings, passed with `--dart-define-from-file=env/<env>.json`
/// (see `env/dev.json.example`). Nothing is read at run time.
abstract final class AppConfig {
  /// Backend API root including `/api/v1`, e.g. `https://api.example.com/api/v1`.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  // #if push
  // Firebase, for push. All empty = no Firebase: the app runs and push is
  // reported as unavailable. Take the values from your own Firebase project
  // and put them in env/dev.json (git-ignored); never commit them.
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
  // #endif

  // #if social-login-google|social-login-kakao
  // Social sign-in. An empty value hides that provider's button. The native
  // files read their own copy (`ios/Flutter/Social.xcconfig`,
  // `android/social.properties`); the Kakao key is in both places.
  // #endif
  // #if social-login-google
  /// The **web** OAuth client id of the Google Cloud project.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// The iOS OAuth client id; empty = `GIDClientID` of `Info.plist` is used.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  // #endif
  // #if social-login-kakao
  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );
  // #endif

  // #if ads
  /// The real banner ad units of your AdMob app. Empty = Google's test unit.
  /// Only a release build uses them (see `AdUnitIds`).
  static const adsBannerAndroid = String.fromEnvironment('ADS_BANNER_ANDROID');
  static const adsBannerIos = String.fromEnvironment('ADS_BANNER_IOS');
  // #endif

  // #if board
  /// The board this app shows: a board code of your server (`--dart-define BOARD_CODE=...`).
  static const board = String.fromEnvironment(
    'BOARD_CODE',
    defaultValue: 'general',
  );
  // #endif
}
