import 'package:shared_preferences/shared_preferences.dart';

/// What the user has already been shown, kept in local storage:
///
/// * `onboarding_version` - the intro they finished. Raise
///   [onboardingVersion] to show a redesigned intro again.
/// * `last_seen_whats_new_version` - the newest "what's new" they saw. Raise
///   [whatsNewVersion] (and edit `WhatsNewScreen`) when a release adds
///   something worth announcing.
class OnboardingStore {
  OnboardingStore._();

  static const onboardingVersion = 1;
  static const whatsNewVersion = 1;

  static const _onboardingKey = 'onboarding_version';
  static const _whatsNewKey = 'last_seen_whats_new_version';

  static Future<bool> needsOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_onboardingKey) ?? 0) < onboardingVersion;
  }

  static Future<bool> needsWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_whatsNewKey) ?? 0) < whatsNewVersion;
  }

  /// Onboarding finished (or skipped). A brand-new user has nothing to be
  /// told is "new" yet, so the current what's-new is marked seen as well.
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_onboardingKey, onboardingVersion);
    await prefs.setInt(_whatsNewKey, whatsNewVersion);
  }

  /// Someone who was already using the app before onboarding existed: don't
  /// show them the first-install intro, but do keep what's-new pending.
  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_onboardingKey, onboardingVersion);
  }

  static Future<void> completeWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_whatsNewKey, whatsNewVersion);
  }
}
