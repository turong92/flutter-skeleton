/// The texts of the gate's screens. The package does not translate: the app
/// passes its own (defaults are English).
class AppControlLabels {
  const AppControlLabels({
    this.maintenanceTitle = 'We are under maintenance',
    this.maintenanceBody = 'The service is temporarily unavailable. Please try again in a little while.',
    this.maintenanceEnds = 'Expected back around {time}.',
    this.updateRequiredTitle = 'Please update to continue',
    this.updateRequiredBody =
        'This version is no longer supported. Update the app to keep using it.',
    this.update = 'Update',
    this.updateRecommendedTitle = 'A new version is available',
    this.updateRecommendedBody = 'Update the app to get the latest version.',
    this.later = 'Later',
  });

  /// Korean texts, in the polite 해요 style.
  const AppControlLabels.ko()
    : this(
        maintenanceTitle: '지금은 점검 중이에요',
        maintenanceBody: '서비스를 잠시 쓸 수 없어요. 조금 뒤에 다시 들어와 주세요.',
        maintenanceEnds: '{time}쯤 다시 열릴 예정이에요.',
        updateRequiredTitle: '업데이트가 필요해요',
        updateRequiredBody: '이 버전은 더 이상 지원하지 않아요. 앱을 업데이트해 주세요.',
        update: '업데이트',
        updateRecommendedTitle: '새 버전이 나왔어요',
        updateRecommendedBody: '업데이트하면 최신 버전을 쓸 수 있어요.',
        later: '나중에',
      );

  final String maintenanceTitle;

  /// Shown when the operator wrote no message.
  final String maintenanceBody;

  /// One line when an end is expected; `{time}` is replaced by the time.
  final String maintenanceEnds;
  final String updateRequiredTitle;
  final String updateRequiredBody;

  /// The button that opens the store (forced screen and the notice).
  final String update;
  final String updateRecommendedTitle;
  final String updateRecommendedBody;

  /// Closes the recommended notice.
  final String later;
}
