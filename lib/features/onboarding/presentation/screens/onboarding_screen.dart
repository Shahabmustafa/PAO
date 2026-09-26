import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_icons.dart';
import '../../data/onboarding_store.dart';
import '../widgets/onboarding_pager.dart';

/// Shown once, on the first launch after install (before login).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _finish(BuildContext context) async {
    await OnboardingStore.completeOnboarding();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OnboardingPager(
      onFinish: () => _finish(context),
      pages: [
        OnboardingPageData(
          icon: AppIcons.donateFilled,
          title: l10n.onboardingGiveTitle,
          body: l10n.onboardingGiveBody,
        ),
        OnboardingPageData(
          icon: AppIcons.search,
          title: l10n.onboardingFindTitle,
          body: l10n.onboardingFindBody,
        ),
        OnboardingPageData(
          icon: AppIcons.chat,
          title: l10n.onboardingChatTitle,
          body: l10n.onboardingChatBody,
        ),
        OnboardingPageData(
          icon: AppIcons.star,
          title: l10n.onboardingCommunityTitle,
          body: l10n.onboardingCommunityBody,
        ),
      ],
    );
  }
}
