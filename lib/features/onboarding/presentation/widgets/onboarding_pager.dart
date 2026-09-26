import 'package:concentric_transition/concentric_transition.dart';
import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  /// One of the [AppIcons] SVG assets.
  final String icon;
  final String title;
  final String body;
}

/// Pages alternate between the brand lime and black. The count must be even
/// so the last page's button wipes to the first page's colour, not its own.
Color _background(int index) =>
    index.isEven ? AppColors.primary : AppColors.onPrimary;

Color _foreground(int index) =>
    index.isEven ? AppColors.onPrimary : AppColors.primary;

/// Full-screen swipeable intro with the concentric colour-circle transition,
/// used for both the first-install onboarding and the "what's new" tour.
class OnboardingPager extends StatefulWidget {
  const OnboardingPager({
    super.key,
    required this.pages,
    required this.onFinish,
  });

  final List<OnboardingPageData> pages;

  /// Called from the last page's button, or from Skip.
  final VoidCallback onFinish;

  @override
  State<OnboardingPager> createState() => _OnboardingPagerState();
}

class _OnboardingPagerState extends State<OnboardingPager> {
  int _page = 0;

  @override
  void initState() {
    super.initState();
    assert(widget.pages.length.isEven, 'see _background');
  }

  bool get _isLast => _page == widget.pages.length - 1;

  @override
  Widget build(BuildContext context) {
    final foreground = _foreground(_page);
    // The wipe animation is left-to-right whatever the language.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Stack(
          children: [
            ConcentricPageView(
              colors: [
                for (var i = 0; i < widget.pages.length; i++) _background(i),
              ],
              itemCount: widget.pages.length,
              radius: 32,
              verticalPosition: 0.8,
              duration: const Duration(milliseconds: 900),
              onChange: (page) => setState(() => _page = page),
              onFinish: widget.onFinish,
              nextButtonBuilder: (_) => Icon(
                _isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                size: 32,
              ),
              itemBuilder: (index) => _OnboardingPage(
                data: widget.pages[index],
                foreground: _foreground(index),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Dots(
                      count: widget.pages.length,
                      index: _page,
                      color: foreground,
                    ),
                    AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: _isLast ? null : widget.onFinish,
                        style: TextButton.styleFrom(
                          foregroundColor: foreground,
                        ),
                        child: Text(context.l10n.tourSkip),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.foreground});

  final OnboardingPageData data;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Padding(
      // Leaves the bottom fifth to the round next button.
      padding: EdgeInsets.fromLTRB(32, 0, 32, height * 0.22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: foreground.withValues(alpha: 0.1),
              border: Border.all(
                color: foreground.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: Center(
              child: AppIcon(data.icon, size: 84, color: foreground),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.75),
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.color});

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsetsDirectional.only(end: 6),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: i == index ? 1 : 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
