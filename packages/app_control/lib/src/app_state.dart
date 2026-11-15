import 'app_version.dart';
import 'models.dart';

/// What the app shows: maintenance, then a forced update, then a recommended
/// one, otherwise the app itself.
sealed class AppState {
  const AppState();
}

class AppOk extends AppState {
  const AppOk();
}

class AppMaintenance extends AppState {
  const AppMaintenance({this.message, this.endsAt});

  final String? message;
  final DateTime? endsAt;
}

class AppUpdateRequired extends AppState {
  const AppUpdateRequired({required this.minVersion, this.storeUrl});

  final String minVersion;
  final String? storeUrl;
}

class AppUpdateRecommended extends AppState {
  const AppUpdateRecommended({required this.recommendedVersion, this.storeUrl});

  final String recommendedVersion;
  final String? storeUrl;
}

/// Picks what to show from what the server said. Nothing read yet ([config]
/// null), no rule for this [platform] or an unreadable [appVersion] means the
/// app runs: it is only held back when the server says so. [dismissed] is the
/// recommended version the person already closed.
AppState appStateOf(
  AppControlConfig? config, {
  required String? appVersion,
  required String platform,
  String? dismissed,
}) {
  if (config == null) return const AppOk();
  if (config.maintenance.enabled) {
    return AppMaintenance(
      message: config.maintenance.message,
      endsAt: config.maintenance.endsAt,
    );
  }
  final policy = config.platforms[platform];
  if (policy == null || appVersion == null) return const AppOk();
  final min = policy.minVersion;
  if (min != null && isVersionBelow(appVersion, min)) {
    return AppUpdateRequired(minVersion: min, storeUrl: policy.storeUrl);
  }
  final recommended = policy.recommendedVersion;
  if (recommended != null &&
      recommended != dismissed &&
      isVersionBelow(appVersion, recommended)) {
    return AppUpdateRecommended(
      recommendedVersion: recommended,
      storeUrl: policy.storeUrl,
    );
  }
  return const AppOk();
}
