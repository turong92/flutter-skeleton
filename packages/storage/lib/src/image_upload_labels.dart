/// The texts of [ImageUploadField]. The package does not translate: the app
/// passes its own (defaults are English).
class ImageUploadLabels {
  const ImageUploadLabels({
    this.add = 'Add photos',
    this.remove = 'Remove photo',
    this.limitReached = 'No more photos can be added.',
    this.failed = 'Could not upload. Remove it and try again.',
    this.rejected = 'This file cannot be used.',
    this.reasons = const {},
  });

  final String add;

  /// Tooltip and screen-reader label of the remove button on every photo.
  final String remove;
  final String limitReached;

  /// A network or storage failure.
  final String failed;

  /// A refusal whose code is not in [reasons].
  final String rejected;

  /// A sentence per refusal code (`SIZE_TOO_LARGE`, `UNSUPPORTED_CONTENT_TYPE`,
  /// or a code the server sent).
  final Map<String, String> reasons;
}
