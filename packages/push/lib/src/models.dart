/// `GET /push/config`: what the server has switched on.
class PushConfig {
  const PushConfig({
    required this.fcm,
    required this.types,
    required this.advertisingTypes,
  });

  factory PushConfig.fromJson(Map<String, Object?> json) => PushConfig(
    fcm: json['fcm'] == true,
    types: _strings(json['types']),
    advertisingTypes: _strings(json['advertisingTypes']),
  );

  /// Mobile (FCM) delivery is on. Without it a device cannot be registered.
  final bool fcm;

  /// Notification kinds a person may switch off for push.
  final List<String> types;
  final List<String> advertisingTypes;
}

/// One kind's push switch. [allChannelsMuted] means the person turned every
/// channel of the kind off elsewhere (read only here).
class PushPreference {
  const PushPreference({
    required this.type,
    required this.push,
    required this.allChannelsMuted,
  });

  factory PushPreference.fromJson(Map<String, Object?> json) => PushPreference(
    type: json['type']! as String,
    push: json['push'] == true,
    allChannelsMuted: json['allChannelsMuted'] == true,
  );

  final String type;
  final bool push;
  final bool allChannelsMuted;
}

List<String> _strings(Object? value) => [
  if (value is List) for (final v in value) v as String,
];
