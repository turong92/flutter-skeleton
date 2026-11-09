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

  /// Korean texts, in the polite 해요 style.
  const ImageUploadLabels.ko()
    : this(
        add: '사진 추가',
        remove: '사진 지우기',
        limitReached: '더 이상 사진을 추가할 수 없어요.',
        failed: '올리지 못했어요. 지우고 다시 시도해 주세요.',
        rejected: '이 파일은 쓸 수 없어요.',
        reasons: const {
          'SIZE_TOO_LARGE': '파일이 너무 커요.',
          'UNSUPPORTED_CONTENT_TYPE': '올릴 수 없는 종류의 파일이에요.',
          'UNSUPPORTED_EXTENSION': '올릴 수 없는 종류의 파일이에요.',
          'CONTENT_MISMATCH': '파일 내용이 종류와 달라요. 쓸 수 없는 파일이에요.',
          'UNRECOGNIZED_CONTENT': '무슨 파일인지 알 수 없어요.',
          'IMAGE_TOO_LARGE': '사진의 픽셀 수가 너무 많아요.',
          'INSPECTION_REJECTED': '쓸 수 없는 파일이에요.',
        },
      );

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
