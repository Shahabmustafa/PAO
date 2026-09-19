import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/legal_links.dart';
import '../l10n/l10n.dart';

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
      ..onTap = () => LegalLinks.openTerms(context);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => LegalLinks.openPrivacyPolicy(context);
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
    final textStyle = TextStyle(fontSize: 13, color: context.appTextSecondary);

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
                  TextSpan(text: context.l10n.termsAgreePrefix),
                  TextSpan(
                    text: context.l10n.termsAndConditions,
                    style: linkStyle,
                    recognizer: _termsRecognizer,
                  ),
                  TextSpan(text: context.l10n.termsAnd),
                  TextSpan(
                    text: context.l10n.privacyPolicy,
                    style: linkStyle,
                    recognizer: _privacyRecognizer,
                  ),
                  TextSpan(text: context.l10n.termsAgreeSuffix),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
