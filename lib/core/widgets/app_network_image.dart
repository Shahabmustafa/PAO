import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'app_shimmer.dart';

/// Cached network image with a shimmer placeholder while it loads and a
/// custom fallback widget if the load fails.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final WidgetBuilder? errorBuilder;

  /// Width in physical pixels to decode (and keep in the memory cache) the
  /// image at. Photos are uploaded up to 1600 px wide; a small card has no
  /// use for that, so decoding at the size actually shown saves memory and
  /// keeps scrolling smooth. Null decodes at full size.
  final int? memCacheWidth;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.memCacheWidth,
  });

  /// Physical pixel width of [logicalWidth] on this screen.
  static int pixelWidth(BuildContext context, double logicalWidth) =>
      (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      placeholder: (context, url) => const AppShimmer(),
      errorWidget: (context, url, error) =>
          errorBuilder?.call(context) ?? const SizedBox.shrink(),
    );
  }
}
