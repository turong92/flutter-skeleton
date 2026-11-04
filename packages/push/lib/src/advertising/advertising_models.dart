/// One consent as `GET /push/advertising` reports it. [state] is `AGREED`,
/// `EXPIRED`, `OUTDATED`, `WITHDRAWN` or `NONE`.
class AdvertisingConsent {
  const AdvertisingConsent({
    required this.type,
    required this.state,
    required this.agreedAt,
    required this.expiresAt,
    required this.reconfirmDue,
    required this.effective,
  });

  factory AdvertisingConsent.fromJson(Map<String, Object?> json) =>
      AdvertisingConsent(
        type: json['type']! as String,
        state: json['state']! as String,
        agreedAt: json['agreedAt'] as String?,
        expiresAt: json['expiresAt'] as String?,
        reconfirmDue: json['reconfirmDue'] == true,
        effective: json['effective'] == true,
      );

  /// The legal document type (`marketing`, `marketing-night`).
  final String type;
  final String state;
  final String? agreedAt;
  final String? expiresAt;

  /// Agreed and the two years end within the notice period.
  final bool reconfirmDue;

  /// The server would really send now.
  final bool effective;

  /// Shown as on: agreed and the server says it takes effect.
  bool get isOn => state == 'AGREED' && effective;

  /// Expired, or about to: ask again (`source: reconfirm`).
  bool get needsReconfirm => state == 'EXPIRED' || reconfirmDue;
}

class NightWindow {
  const NightWindow({
    required this.start,
    required this.end,
    required this.zone,
  });

  factory NightWindow.fromJson(Map<String, Object?> json) => NightWindow(
    start: json['start']! as String,
    end: json['end']! as String,
    zone: json['zone']! as String,
  );

  final String start;
  final String end;
  final String zone;
}

/// `GET /push/advertising`: the caller's promotional-push consent state.
class Advertising {
  const Advertising({
    required this.senderName,
    required this.consent,
    required this.night,
    required this.nightWindow,
  });

  factory Advertising.fromJson(Map<String, Object?> json) => Advertising(
    senderName: json['senderName']! as String,
    consent: AdvertisingConsent.fromJson(
      json['consent']! as Map<String, Object?>,
    ),
    night: AdvertisingConsent.fromJson(json['night']! as Map<String, Object?>),
    nightWindow: NightWindow.fromJson(
      json['nightWindow']! as Map<String, Object?>,
    ),
  );

  final String senderName;
  final AdvertisingConsent consent;
  final AdvertisingConsent night;
  final NightWindow nightWindow;

  /// Night counts only while advertising itself is on: a night agreement the
  /// server still holds does nothing without it.
  bool get nightOn => night.isOn && consent.isOn;
}
