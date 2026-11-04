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

  /// Return addresses of the payment window. They are never opened: the window
  /// is stopped on the way there. Any fixed https addresses of your project.
  static final paymentSuccessUrl = Uri.parse(
    'https://checkout.example.com/pay/success',
  );
  static final paymentFailUrl = Uri.parse(
    'https://checkout.example.com/pay/fail',
  );
}
