import 'package:flutter/material.dart';

import 'stored_image.dart';

/// A [StoredImage] that keeps the picture it has drawn while a new address
/// loads. A signed address changes every time the server is asked again; the
/// plain image would show its waiting box in between and the picture would
/// blink. The new address is fetched ahead, and the picture is swapped when it
/// is there (or has failed, so the failure shows).
class HeldImage extends StatefulWidget {
  const HeldImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String url;
  final int? width;
  final int? height;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  State<HeldImage> createState() => _HeldImageState();
}

class _HeldImageState extends State<HeldImage> {
  late String _shown = widget.url;

  @override
  void didUpdateWidget(HeldImage old) {
    super.didUpdateWidget(old);
    if (widget.url != old.url) _swapWhenLoaded(widget.url);
  }

  Future<void> _swapWhenLoaded(String url) async {
    await precacheImage(NetworkImage(url), context, onError: (_, _) {});
    // A newer address may have come while this one loaded: it wins.
    if (mounted && widget.url == url) setState(() => _shown = url);
  }

  @override
  Widget build(BuildContext context) => StoredImage(
    url: _shown,
    width: widget.width,
    height: widget.height,
    fit: widget.fit,
    semanticLabel: widget.semanticLabel,
  );
}
