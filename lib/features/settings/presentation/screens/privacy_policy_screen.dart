import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';
import 'legal_document_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LegalDocumentScreen(
      title: l10n.privacyPolicy,
      lastUpdated: l10n.privacyDate,
      sections: [
        LegalSection(l10n.privacy1Title, l10n.privacy1Body),
        LegalSection(l10n.privacy2Title, l10n.privacy2Body),
        LegalSection(l10n.privacy3Title, l10n.privacy3Body),
        LegalSection(l10n.privacy4Title, l10n.privacy4Body),
        LegalSection(l10n.privacy5Title, l10n.privacy5Body),
        LegalSection(l10n.privacy6Title, l10n.privacy6Body),
        LegalSection(l10n.privacy7Title, l10n.privacy7Body),
        LegalSection(l10n.privacy8Title, l10n.privacy8Body),
        LegalSection(l10n.privacy9Title, l10n.privacy9Body),
        LegalSection(l10n.privacy10Title, l10n.privacy10Body),
      ],
    );
  }
}
