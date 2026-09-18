import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// A single shimmering placeholder block. Use to build loading skeletons
/// for anything still being fetched from Supabase (images, profile rows,
/// lists, ...).
class AppShimmer extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const AppShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColorsDark.surface : AppColors.border,
      highlightColor: isDark ? AppColorsDark.border : AppColors.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.surface : Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
