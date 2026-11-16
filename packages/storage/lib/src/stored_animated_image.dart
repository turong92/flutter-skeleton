import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'models.dart';
import 'stored_image.dart';

/// The display copy of a stored image, played as a silent looping video when
/// the server made one (an animated image: [ImageVariant.videoUrl]).
///
/// Until the video is ready it shows the still picture ([thumb] when given,
/// else [display]), so nothing blinks. When there is no video, or the player
/// cannot start or stops on an error, it stays the [StoredImage] of [display].
/// Off screen it pauses; back on screen it plays again.
///
/// Addresses are made drawable with [resolveStoredUrl] against [apiBaseUrl],
/// as for [StoredImage].
class StoredAnimatedImage extends StatefulWidget {
  const StoredAnimatedImage({
    super.key,
    required this.display,
    required this.apiBaseUrl,
    this.thumb,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final ImageVariant display;
  final ImageVariant? thumb;
  final String apiBaseUrl;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  State<StoredAnimatedImage> createState() => _StoredAnimatedImageState();
}

class _StoredAnimatedImageState extends State<StoredAnimatedImage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.display.videoUrl;
    if (videoUrl != null) _start(resolveStoredUrl(videoUrl, widget.apiBaseUrl));
  }

  Future<void> _start(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.addListener(_onValue);
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (_visible) await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _fail();
    }
  }

  void _onValue() {
    if (_controller?.value.hasError ?? false) _fail();
  }

  void _fail() {
    if (mounted && !_failed) setState(() => _failed = true);
  }

  void _onVisibility(VisibilityInfo info) {
    _visible = info.visibleFraction > 0;
    final controller = _controller;
    if (controller == null || !_ready || _failed) return;
    if (_visible) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onValue);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.display;
    String address(ImageVariant v) =>
        resolveStoredUrl(v.url, widget.apiBaseUrl);
    StoredImage picture(ImageVariant v) => StoredImage(
      url: address(v),
      width: display.width,
      height: display.height,
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
    );

    final controller = _controller;
    if (controller == null || _failed) return picture(display);
    return VisibilityDetector(
      key: ObjectKey(this),
      onVisibilityChanged: _onVisibility,
      child: _ready
          ? AspectRatio(
              aspectRatio: display.width / display.height,
              child: FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          : picture(widget.thumb ?? display),
    );
  }
}
