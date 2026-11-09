/// The texts of the legal widgets. The package does not translate: the app
/// passes its own (defaults are English).
class LegalLabels {
  const LegalLabels({
    this.required = 'Required',
    this.optional = 'Optional',
    this.view = 'Read',
    this.retry = 'Try again',
    this.loadFailed = 'Could not load the documents.',
    this.reconsentTitle = 'Our terms have changed',
    this.reconsentBody = 'Please read and agree to continue.',
    this.agree = 'Agree and continue',
    this.agreeFailed = 'Could not save your agreement. Please try again.',
    this.signOut = 'Sign out',
  });

  /// Korean texts, in the polite 해요 style.
  const LegalLabels.ko()
    : this(
        required: '필수',
        optional: '선택',
        view: '보기',
        retry: '다시 시도',
        loadFailed: '약관을 불러오지 못했어요.',
        reconsentTitle: '약관이 바뀌었어요',
        reconsentBody: '계속 이용하려면 바뀐 문서를 읽고 동의해 주세요.',
        agree: '동의하고 계속하기',
        agreeFailed: '동의를 저장하지 못했어요. 다시 시도해 주세요.',
        signOut: '로그아웃',
      );

  /// Next to a document that has to be agreed to.
  final String required;

  /// Next to a document that may be left unchecked.
  final String optional;

  /// The button that opens a document.
  final String view;
  final String retry;
  final String loadFailed;
  final String reconsentTitle;
  final String reconsentBody;
  final String agree;
  final String agreeFailed;

  /// The way out of the consent screen (see `ReconsentScreen.onLeave`).
  final String signOut;
}
