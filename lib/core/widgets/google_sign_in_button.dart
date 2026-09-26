import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// "OR" divider followed by a "Continue with Google" button, shared by the
/// login and signup screens.
class GoogleSignInSection extends StatelessWidget {
  const GoogleSignInSection({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final bool enabled;

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
            onPressed: enabled ? onPressed : null,
            icon: const Text(
              'G',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDB4437),
              ),
            ),
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
