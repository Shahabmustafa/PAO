import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/settings/presentation/screens/terms_conditions_screen.dart';

/// Hosted copies of the legal documents (the same URLs registered in the
/// Google Play Console), so the app and the store listing always agree.
class LegalLinks {
  LegalLinks._();

  static const String privacyPolicyUrl =
      'https://shahabmustafa.github.io/PAO/privacy_policy.html';
  static const String termsUrl =
      'https://shahabmustafa.github.io/PAO/terms.html';
  static const String deleteAccountUrl =
      'https://shahabmustafa.github.io/PAO/delete-account.html';

  static Future<void> openPrivacyPolicy(BuildContext context) => _open(
    context,
    privacyPolicyUrl,
    fallback: (_) => const PrivacyPolicyScreen(),
  );

  static Future<void> openTerms(BuildContext context) =>
      _open(context, termsUrl, fallback: (_) => const TermsConditionsScreen());

  /// Opens [url] in an in-app browser tab. If it can't be opened (no browser,
  /// no connection handling by the OS, ...), shows the bundled offline copy
  /// of the document instead.
  static Future<void> _open(
    BuildContext context,
    String url, {
    required WidgetBuilder fallback,
  }) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppBrowserView,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: fallback));
  }
}
