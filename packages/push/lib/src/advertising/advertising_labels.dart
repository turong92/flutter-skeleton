/// The texts of `AdvertisingSettingsView`. The package does not translate: the
/// app passes its own (defaults are English).
class AdvertisingLabels {
  const AdvertisingLabels({
    this.title = 'Promotional notifications',
    this.description = _description,
    this.loadFailed = 'Could not load your promotional settings.',
    this.retry = 'Try again',
    this.consentTitle = 'Receive promotional notifications',
    this.consentDescription =
        'Offers and news. Off by default; you can withdraw at any time.',
    this.agreedUntil = _agreedUntil,
    this.agree = 'Agree',
    this.stopped = 'You are not receiving promotional notifications.',
    this.nightTitle = 'Also receive them at night',
    this.nightDescription = _nightDescription,
    this.nightLocked = 'Agree to promotional notifications first.',
    this.reconfirmDueTitle = _dueTitle,
    this.reconfirmDueDescription =
        'Consent to promotional notifications is confirmed every two years.',
    this.reconfirmDueAction = 'Confirm',
    this.reconfirmExpiredTitle = 'Your consent has expired, so you are not receiving promotional notifications',
    this.reconfirmExpiredDescription = 'Agree again to start receiving them.',
    this.reconfirmExpiredAction = 'Agree again',
    this.documentCheck = 'I have read this and agree',
    this.documentConfirm = 'Agree and receive',
    this.agreeFailed = 'Could not save your consent. Try again.',
    this.documentChanged = 'The document has changed. Read it again and agree.',
    this.agreed = _agreed,
    this.withdrawTitle = 'Stop promotional notifications?',
    this.withdrawDescription =
        'You will stop receiving them right away. You can agree again later.',
    this.withdrawAlsoNight = 'Night notifications are turned off too.',
    this.withdrawConfirm = 'Withdraw consent',
    this.withdrawCancel = 'Keep receiving',
    this.withdrawn = _withdrawn,
    this.withdrawFailed = 'Could not withdraw your consent. Try again.',
  });

  final String title;

  /// Names the sender and says the service works without consent.
  final String Function(String senderName) description;
  final String loadFailed;
  final String retry;
  final String consentTitle;
  final String consentDescription;
  final String Function(String agreedAt, String expiresAt) agreedUntil;
  final String agree;

  /// After a withdrawal or an expiry.
  final String stopped;
  final String nightTitle;
  final String Function(String start, String end, String zone) nightDescription;
  final String nightLocked;
  final String Function(int daysLeft) reconfirmDueTitle;
  final String reconfirmDueDescription;
  final String reconfirmDueAction;
  final String reconfirmExpiredTitle;
  final String reconfirmExpiredDescription;
  final String reconfirmExpiredAction;

  /// The box under the document; it starts unchecked.
  final String documentCheck;
  final String documentConfirm;
  final String agreeFailed;

  /// A newer version came out while the document was open (409
  /// LEGAL.VERSION_STALE): the new one is shown.
  final String documentChanged;
  final String Function(String when) agreed;
  final String withdrawTitle;
  final String withdrawDescription;

  /// Added to the confirm when night agreement is withdrawn with it.
  final String withdrawAlsoNight;
  final String withdrawConfirm;
  final String withdrawCancel;
  final String Function(String when) withdrawn;
  final String withdrawFailed;

  static String _description(String sender) =>
      'Choose whether $sender may send you promotional push notifications. '
      'You can use the service either way.';
  static String _agreedUntil(String agreedAt, String expiresAt) =>
      'Agreed on $agreedAt · confirm again by $expiresAt';
  static String _nightDescription(String start, String end, String zone) =>
      'Promotional notifications between $start and $end ($zone) need your '
      'separate consent.';
  static String _dueTitle(int days) => 'Please confirm your consent (D-$days)';
  static String _agreed(String when) => 'Agreed ($when).';
  static String _withdrawn(String when) => 'Withdrawn ($when).';
}
