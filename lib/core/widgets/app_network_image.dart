import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'app_shimmer.dart';

/// Cached network image with a shimmer placeholder while it loads and a
/// custom fallback widget if the load fails.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final WidgetBuilder? errorBuilder;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      placeholder: (context, url) => const AppShimmer(),
      errorWidget: (context, url, error) =>
          errorBuilder?.call(context) ?? const SizedBox.shrink(),
    );
  }
}
