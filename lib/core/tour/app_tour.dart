import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// GlobalKeys for the widgets the feature tours point at. Each is attached
/// to exactly one widget in the tree.
class TourKeys {
  TourKeys._();

  static final homeSearch = GlobalKey(debugLabel: 'tour.homeSearch');
  static final homeFilter = GlobalKey(debugLabel: 'tour.homeFilter');
  static final navWishlist = GlobalKey(debugLabel: 'tour.navWishlist');
  static final navAdd = GlobalKey(debugLabel: 'tour.navAdd');
  static final navRequests = GlobalKey(debugLabel: 'tour.navRequests');
  static final navSettings = GlobalKey(debugLabel: 'tour.navSettings');
  static final requestsTabs = GlobalKey(debugLabel: 'tour.requestsTabs');
}

/// One highlighted widget and what to say about it.
class TourStep {
  const TourStep({
    required this.key,
    required this.title,
    required this.body,
    this.circle = false,
    this.above = false,
  });

  final GlobalKey key;
  final String title;
  final String body;

  /// Circular highlight (round buttons) instead of a rounded rectangle.
  final bool circle;

  /// Show the text above the widget instead of below (for the bottom bar).
  final bool above;
}

/// First-run feature tours (coach marks) that spotlight real buttons and
/// say what each one is for. Every tour is identified by an id and shown
/// once; Settings can replay them all via [reset].
class AppTour {
  AppTour._();

  /// Switched off by widget tests so an overlay never covers the screen.
  static bool autoStart = true;

  /// Bumped by Settings' "App tour" tile; the dashboard listens and replays.
  static final ValueNotifier<int> replayRequests = ValueNotifier<int>(0);

  static bool _showing = false;
  static bool get isShowing => _showing;

  static String _prefsKey(String id) => 'tour_seen_$id';

  /// Shows tour [id] if the user hasn't seen it yet.
  static Future<void> maybeShow(
    BuildContext context,
    String id,
    List<TourStep> Function(BuildContext context) buildSteps,
  ) async {
    if (!autoStart || _showing) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsKey(id)) ?? false) return;
      if (!context.mounted) return;
      final shown = show(context, buildSteps(context));
      // Mark as seen only once it actually appeared, so a tour that had
      // nothing on screen to point at gets another chance next time.
      if (shown) await prefs.setBool(_prefsKey(id), true);
    } catch (_) {
      // A tour is a nicety; never let it break the screen.
    }
  }

  /// Shows [steps] now. Steps whose widget isn't on screen are dropped.
  /// Returns whether a tour was started.
  static bool show(BuildContext context, List<TourStep> steps) {
    if (_showing) return false;
    final visible = [
      for (final s in steps)
        if (s.key.currentContext?.findRenderObject() is RenderBox &&
            (s.key.currentContext!.findRenderObject()! as RenderBox).attached)
          s,
    ];
    if (visible.isEmpty) return false;
    _showing = true;

    void done() => _showing = false;
    final total = visible.length;
    final l10n = context.l10n;

    TutorialCoachMark(
      targets: [
        for (var i = 0; i < total; i++)
          TargetFocus(
            identify: 'step_$i',
            keyTarget: visible[i].key,
            shape: visible[i].circle
                ? ShapeLightFocus.Circle
                : ShapeLightFocus.RRect,
            radius: 16,
            enableOverlayTab: true,
            contents: [
              TargetContent(
                align: visible[i].above
                    ? ContentAlign.top
                    : ContentAlign.bottom,
                builder: (ctx, controller) => _StepCard(
                  step: visible[i],
                  index: i,
                  total: total,
                  nextLabel: i == total - 1 ? l10n.tourDone : l10n.tourNext,
                  onNext: controller.next,
                ),
              ),
            ],
          ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      textSkip: l10n.tourSkip,
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      paddingFocus: 6,
      onFinish: done,
      onSkip: () {
        done();
        return true;
      },
    ).show(context: context);
    return true;
  }

  /// Forgets every tour, so each shows again the next time its screen opens.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (k) => k.startsWith('tour_seen_'),
    )) {
      await prefs.remove(key);
    }
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.index,
    required this.total,
    required this.nextLabel,
    required this.onNext,
  });

  final TourStep step;
  final int index;
  final int total;
  final String nextLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${index + 1} / $total',
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: Text(nextLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
