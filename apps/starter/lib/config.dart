/// Build-time settings, passed with `--dart-define-from-file=env/<env>.json`
/// (see `env/dev.json.example`). Nothing is read at run time.
abstract final class AppConfig {
  /// Backend API root including `/api/v1`, e.g. `https://api.example.com/api/v1`.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}
