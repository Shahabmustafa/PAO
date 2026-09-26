import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// "OR" divider followed by a "Continue with Google" button, shared by the
/// login and signup screens.
class GoogleSignInSection extends StatelessWidget {
  const GoogleSignInSection({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
  });

  final VoidCallback onPressed;
  final bool enabled;

  /// Shows a spinner in place of the Google logo and blocks taps.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                context.l10n.orDivider,
                style: TextStyle(color: context.appTextSecondary),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: enabled && !isLoading ? onPressed : null,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SvgPicture.asset(AppIcons.google, width: 20, height: 20),
            label: Text(
              context.l10n.continueWithGoogle,
              style: TextStyle(color: context.appTextPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
