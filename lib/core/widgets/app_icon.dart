import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders one of the app's SVG icons (see [AppIcons]), replacing the use
/// of Flutter's built-in Material [Icons].
class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  const AppIcon(this.asset, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: tint != null
          ? ColorFilter.mode(tint, BlendMode.srcIn)
          : null,
    );
  }
}
