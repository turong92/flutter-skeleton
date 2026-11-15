/// `GET /api/v1/app/config` (kotlin-skeleton `docs/app-control-http-contract.md`).
class AppControlConfig {
  const AppControlConfig({
    required this.serverTime,
    required this.maintenance,
    required this.flags,
    required this.platforms,
  });

  factory AppControlConfig.fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    final flags = (map['flags'] as Map<String, Object?>?) ?? const {};
    final platforms = (map['platforms'] as Map<String, Object?>?) ?? const {};
    return AppControlConfig(
      serverTime: DateTime.parse(map['serverTime']! as String),
      maintenance: MaintenanceInfo.fromJson(map['maintenance']),
      flags: {for (final e in flags.entries) e.key: e.value == true},
      platforms: {
        for (final e in platforms.entries)
          e.key: PlatformPolicy.fromJson(e.value),
      },
    );
  }

  final DateTime serverTime;
  final MaintenanceInfo maintenance;

  /// The switches the operator made visible to clients. A missing key is off.
  final Map<String, bool> flags;

  /// Version rules by platform name (`android`, `ios`, ...).
  final Map<String, PlatformPolicy> platforms;
}

class MaintenanceInfo {
  const MaintenanceInfo({required this.enabled, this.message, this.endsAt});

  factory MaintenanceInfo.fromJson(Object? json) {
    final map = (json as Map<String, Object?>?) ?? const {};
    final endsAt = map['endsAt'] as String?;
    return MaintenanceInfo(
      enabled: map['enabled'] == true,
      message: map['message'] as String?,
      endsAt: endsAt == null ? null : DateTime.parse(endsAt),
    );
  }

  final bool enabled;

  /// Only while maintenance is on.
  final String? message;

  /// When the operator expects it to end, if they said.
  final DateTime? endsAt;
}

/// One platform's version rules; a null part is a rule that is not set.
class PlatformPolicy {
  const PlatformPolicy({
    this.minVersion,
    this.recommendedVersion,
    this.storeUrl,
  });

  factory PlatformPolicy.fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return PlatformPolicy(
      minVersion: map['minVersion'] as String?,
      recommendedVersion: map['recommendedVersion'] as String?,
      storeUrl: map['storeUrl'] as String?,
    );
  }

  /// Lower than this: a forced update.
  final String? minVersion;

  /// Lower than this: an update the person may close.
  final String? recommendedVersion;
  final String? storeUrl;
}
