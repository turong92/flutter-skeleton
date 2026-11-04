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
