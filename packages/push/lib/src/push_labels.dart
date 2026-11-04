/// The texts of the push widgets. The package does not translate: the app
/// passes its own (defaults are English).
class PushLabels {
  const PushLabels({
    this.promptTitle = 'Get notified about what matters to you.',
    this.promptEnable = 'Turn on notifications',
    this.deniedHelp =
        'Notifications are blocked. Turn them on in your device settings.',
    this.unavailable = 'Notifications are not available in this app.',
    this.deviceSwitch = 'Notifications on this device',
    this.kindsTitle = 'Notify me about',
    this.allChannelsMuted = 'Turned off for every channel',
    this.testSend = 'Send a test notification',
    this.testSent = 'Sent. It should arrive in a moment.',
    this.testTooSoon = 'One test a minute. Try again shortly.',
    this.testFailed = 'Could not send the test.',
    this.loadFailed = 'Could not load.',
    this.retry = 'Try again',
    this.typeName = _same,
  });

  final String promptTitle;
  final String promptEnable;

  /// Shown after the system refused: the app cannot ask again, only point to
  /// the settings.
  final String deniedHelp;
  final String unavailable;
  final String deviceSwitch;
  final String kindsTitle;
  final String allChannelsMuted;
  final String testSend;
  final String testSent;
  final String testTooSoon;
  final String testFailed;
  final String loadFailed;
  final String retry;

  /// The name of a notification kind (`COMMENT`) in the person's language.
  final String Function(String type) typeName;

  static String _same(String type) => type;
}
