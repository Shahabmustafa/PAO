import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_icons.dart';
import '../../data/onboarding_store.dart';
import '../widgets/onboarding_pager.dart';

/// Shown once to returning users after an update that adds something
/// important. Edit the pages and raise [OnboardingStore.whatsNewVersion]
/// for the next announcement.
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  Future<void> _finish(BuildContext context) async {
    await OnboardingStore.completeWhatsNew();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OnboardingPager(
      onFinish: () => _finish(context),
      pages: [
        OnboardingPageData(
          icon: AppIcons.camera,
          title: l10n.whatsNewMediaTitle,
          body: l10n.whatsNewMediaBody,
        ),
        OnboardingPageData(
          icon: AppIcons.checkCircle,
          title: l10n.whatsNewOfflineTitle,
          body: l10n.whatsNewOfflineBody,
        ),
        OnboardingPageData(
          icon: AppIcons.star,
          title: l10n.whatsNewDonorsTitle,
          body: l10n.whatsNewDonorsBody,
        ),
        OnboardingPageData(
          icon: AppIcons.lightbulb,
          title: l10n.whatsNewFastTitle,
          body: l10n.whatsNewFastBody,
        ),
      ],
    );
  }
}
