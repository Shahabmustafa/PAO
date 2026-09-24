import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_shimmer.dart';

const _kDefaultAvatarAsset = 'assets/images/profile.jpg';

/// Circular profile photo with a shimmer placeholder while it loads and a
/// person-icon fallback when there's no photo (or it fails to load).
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;

  /// Adds a subtle border + shadow ring around the photo, for avatars shown
  /// on their own (profile headers, tappable greeting avatars) rather than
  /// inline in a list.
  final bool ring;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.radius = 22,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final innerSize = ring ? size - 4 : size;

    final photo = ClipOval(
      child: SizedBox(
        width: innerSize,
        height: innerSize,
        child: imageUrl == null
            ? _Fallback(size: innerSize)
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                memCacheWidth:
                    (innerSize * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                placeholder: (context, url) => AppShimmer(
                  width: innerSize,
                  height: innerSize,
                  borderRadius: BorderRadius.circular(innerSize / 2),
                ),
                errorWidget: (context, url, error) =>
                    _Fallback(size: innerSize),
              ),
      ),
    );

    if (!ring) return photo;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.appSurface,
        border: Border.all(color: context.appBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: photo,
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
