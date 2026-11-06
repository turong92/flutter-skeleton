import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The place for the profile picture. The package does not upload anything:
/// the app puts its own field here (`ImageUploadField` of `skeleton_storage`
/// with `max: 1`), so `auth` does not know `storage`.
///
/// [value] is the key now chosen (null = none). Call [onChanged] with the key
/// of a finished upload, or null when the person removes the picture. Call
/// [onBusy] with true while a file is going up and false when it is over: the
/// key arrives only after the upload, so a save in between would leave the
/// photo out.
typedef ProfilePicturePicker = Widget Function(
  BuildContext context,
  String? value,
  ValueChanged<String?> onChanged,
  ValueChanged<bool> onBusy,
);

/// The texts of [ProfilePictureSection] (defaults are English).
class ProfilePictureLabels {
  const ProfilePictureLabels({
    this.title = 'Profile picture',
    this.save = 'Save picture',
    this.pending = 'Your picture is being prepared. It will show up shortly.',
    this.rejected =
        'This photo cannot be used. Please upload a new image file.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  /// Korean texts, in the polite 해요 style.
  const ProfilePictureLabels.ko()
    : this(
        title: '프로필 사진',
        save: '사진 저장',
        pending: '사진을 준비하고 있어요. 곧 보여요.',
        rejected: '이 사진은 쓸 수 없어요. 다른 이미지 파일을 올려 주세요.',
        networkError: '연결할 수 없어요. 인터넷 연결을 확인해 주세요.',
        genericError: '문제가 생겼어요. 다시 시도해 주세요.',
      );

  final String title;
  final String save;

  /// While the server converts the picture the person just saved.
  final String pending;

  /// The server refused the key (400 with no field error): not the person's
  /// own upload, not an image, or a file another place already uses.
  final String rejected;
  final String networkError;
  final String genericError;
}

/// The profile picture of the account: the current picture, the app's picker,
/// and a save button that waits while a photo is going up. Draw it only for
/// `AccountMe.avatarEnabled`; on a server without `storage` it draws nothing.
/// [onSaved] gets the account as the server now has it.
///
/// [resolveUrl] turns an address without a host (a server whose public base is
/// a path) into one the image can load.
class ProfilePictureSection extends ConsumerStatefulWidget {
  const ProfilePictureSection({
    super.key,
    required this.me,
    required this.picker,
    this.onSaved,
    this.resolveUrl,
    this.labels = const ProfilePictureLabels(),
  });

  static const saveKey = Key('skeleton_auth.profile_picture.save');

  final AccountMe me;
  final ProfilePicturePicker picker;
  final void Function(AccountMe account)? onSaved;
  final String Function(String url)? resolveUrl;
  final ProfilePictureLabels labels;

  @override
  ConsumerState<ProfilePictureSection> createState() =>
      _ProfilePictureSectionState();
}

class _ProfilePictureSectionState extends ConsumerState<ProfilePictureSection> {
  late String? _key = widget.me.avatarKey;
  var _uploading = false;
  var _busy = false;
  String? _error;

  ProfilePictureLabels get labels => widget.labels;

  Future<void> _save() async {
    if (_busy || _uploading) return;
    if (_key == widget.me.avatarKey) {
      widget.onSaved?.call(widget.me);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final me = await ref.read(accountApiProvider).updateAvatar(_key);
      if (!mounted) return;
      setState(() => _key = me.avatarKey);
      widget.onSaved?.call(me);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorText(Object error) {
    if (error is! ApiRequestError) return labels.genericError;
    if (error.apiError.status == 400 && error.apiError.errors.isEmpty) {
      return labels.rejected;
    }
    return error.code == ClientErrorCodes.networkError
        ? labels.networkError
        : labels.genericError;
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    if (!me.avatarEnabled) return const SizedBox.shrink();
    final thumb = me.avatar?.thumbUrl;
    final shown = thumb == null
        ? null
        : (widget.resolveUrl?.call(thumb) ?? thumb);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(labels.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (shown != null && _key == me.avatarKey)
          Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(shown),
              onBackgroundImageError: (_, _) {},
            ),
          ),
        if (me.avatar?.pending == true && _key == me.avatarKey)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(labels.pending),
          ),
        const SizedBox(height: 8),
        widget.picker(
          context,
          _key,
          (key) => setState(() {
            _key = key;
            // another photo: the refusal was about the old one
            if (_error == labels.rejected) _error = null;
          }),
          (busy) {
            if (mounted) setState(() => _uploading = busy);
          },
        ),
        if (_error != null) ErrorText(_error!),
        const SizedBox(height: 8),
        SubmitButton(
          key: ProfilePictureSection.saveKey,
          label: labels.save,
          busy: _busy,
          onPressed: _uploading ? null : _save,
        ),
      ],
    );
  }
}
