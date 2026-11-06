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

  /// Korean texts, in the polite 해요 style.
  const PushLabels.ko()
    : this(
        promptTitle: '중요한 소식을 알림으로 받아 보세요.',
        promptEnable: '알림 켜기',
        deniedHelp: '알림이 막혀 있어요. 기기 설정에서 알림을 허용해 주세요.',
        unavailable: '이 앱에서는 알림을 쓸 수 없어요.',
        deviceSwitch: '이 기기에서 알림 받기',
        kindsTitle: '받을 알림',
        allChannelsMuted: '모든 채널에서 꺼져 있어요',
        testSend: '시험 알림 보내기',
        testSent: '보냈어요. 곧 도착할 거예요.',
        testTooSoon: '시험 알림은 1분에 한 번만 보낼 수 있어요. 잠시 뒤에 다시 해 주세요.',
        testFailed: '시험 알림을 보내지 못했어요.',
        loadFailed: '불러오지 못했어요.',
        retry: '다시 시도',
        // the names of the notification kinds are the app's (its kinds)
        typeName: _same,
      );

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
