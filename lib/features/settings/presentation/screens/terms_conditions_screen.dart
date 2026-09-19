import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';
import 'legal_document_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LegalDocumentScreen(
      title: l10n.termsAndConditions,
      lastUpdated: l10n.legalDate,
      sections: [
        LegalSection(l10n.terms1Title, l10n.terms1Body),
        LegalSection(l10n.terms2Title, l10n.terms2Body),
        LegalSection(l10n.terms3Title, l10n.terms3Body),
        LegalSection(l10n.terms4Title, l10n.terms4Body),
        LegalSection(l10n.terms5Title, l10n.terms5Body),
        LegalSection(l10n.terms6Title, l10n.terms6Body),
        LegalSection(l10n.terms7Title, l10n.terms7Body),
        LegalSection(l10n.terms8Title, l10n.terms8Body),
        LegalSection(l10n.terms9Title, l10n.terms9Body),
        LegalSection(l10n.terms10Title, l10n.terms10Body),
        LegalSection(l10n.terms11Title, l10n.terms11Body),
      ],
    );
  }
}
