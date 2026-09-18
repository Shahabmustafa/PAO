import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/settings/presentation/screens/terms_conditions_screen.dart';

/// A checkbox + inline text used on the login and signup screens to make the
/// user acknowledge the app's Terms & Conditions and Privacy Policy before
/// continuing.
class TermsAcceptanceCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const TermsAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<TermsAcceptanceCheckbox> createState() =>
      _TermsAcceptanceCheckboxState();
}

class _TermsAcceptanceCheckboxState extends State<TermsAcceptanceCheckbox> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
      );
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
      );
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      fontSize: 13,
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    );
    const textStyle = TextStyle(fontSize: 13, color: AppColors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: widget.value,
            onChanged: (value) => widget.onChanged(value ?? false),
            activeColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: RichText(
              text: TextSpan(
                style: textStyle,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: linkStyle,
                    recognizer: _termsRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: linkStyle,
                    recognizer: _privacyRecognizer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
