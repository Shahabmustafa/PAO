import 'package:flutter/material.dart';
import '../../../../core/routes/app_navigator.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../onboarding/data/onboarding_store.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final isLoggedIn = AuthRepository().isLoggedIn;
    final openedFromResetLink = AppNavigator.takePendingRecovery();
    final route = openedFromResetLink
        ? AppRoutes.resetPassword
        : await _nextRoute(isLoggedIn);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  /// Launch → first install? onboarding → logged in? → new feature? what's
  /// new → home.
  Future<String> _nextRoute(bool isLoggedIn) async {
    if (await OnboardingStore.needsOnboarding()) {
      if (!isLoggedIn) return AppRoutes.onboarding;
      // Already using the app from before onboarding existed.
      await OnboardingStore.markOnboardingSeen();
    }
    if (!isLoggedIn) return AppRoutes.login;
    if (await OnboardingStore.needsWhatsNew()) return AppRoutes.whatsNew;
    return AppRoutes.dashboard;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/splash_logo.png', width: 240),
            const SizedBox(height: 40),
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
