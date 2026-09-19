import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders one of the app's SVG icons (see [AppIcons]), replacing the use
/// of Flutter's built-in Material [Icons].
class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  /// Flips the icon horizontally in right-to-left languages. Set this for
  /// directional icons (like a chevron), not for symmetric ones.
  final bool mirrorInRtl;

  const AppIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
    this.mirrorInRtl = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      matchTextDirection: mirrorInRtl,
      colorFilter: tint != null
          ? ColorFilter.mode(tint, BlendMode.srcIn)
          : null,
    );
  }
}
