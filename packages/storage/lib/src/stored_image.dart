import 'package:flutter/material.dart';

/// Makes a stored address drawable. A server whose public base is a path
/// (`/files/...`) gives an address without host; it is taken relative to the
/// host of [apiBaseUrl]. A full address is returned as it is.
String resolveStoredUrl(String url, String apiBaseUrl) {
  final parsed = Uri.parse(url);
  return parsed.hasScheme
      ? url
      : Uri.parse(apiBaseUrl).resolveUri(parsed).toString();
}

/// A picture the server stored, drawn from its address. The address comes from
/// the record that holds the key (a post's `attachmentUrls`, or an image
/// variant) or from a signed link the server gave for a private file.
///
/// Give [width] and [height] when the server told them: the place is kept
/// before the picture arrives, so the screen does not jump.
class StoredImage extends StatelessWidget {
  const StoredImage({
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder(IconData icon) => ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(child: Icon(icon, color: scheme.outline)),
    );
    final image = Image.network(
      url,
      fit: fit,
      semanticLabel: semanticLabel,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder(Icons.image_outlined),
      errorBuilder: (context, error, stack) =>
          placeholder(Icons.broken_image_outlined),
    );
    final w = width;
    final h = height;
    return w != null && h != null && w > 0 && h > 0
        ? AspectRatio(aspectRatio: w / h, child: image)
        : image;
  }
}
