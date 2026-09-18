import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'app_shimmer.dart';

const _kDefaultAvatarAsset = 'assets/images/profile.jpg';

/// Circular profile photo with a shimmer placeholder while it loads and a
/// person-icon fallback when there's no photo (or it fails to load).
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;

  const AppAvatar({super.key, this.imageUrl, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? _Fallback(size: size)
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => AppShimmer(
                  width: size,
                  height: size,
                  borderRadius: BorderRadius.circular(radius),
                ),
                errorWidget: (context, url, error) => _Fallback(size: size),
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final double size;

  const _Fallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _kDefaultAvatarAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
