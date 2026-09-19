import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/l10n/l10n.dart';

class LegalSection {
  final String heading;
  final String body;

  const LegalSection(this.heading, this.body);
}

/// Shared scaffold for rendering a legal document (Terms & Conditions,
/// Privacy Policy, ...) as a title, a "last updated" date, and a list of
/// heading/body sections.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              context.l10n.legalLastUpdated(lastUpdated),
              style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            ),
            const SizedBox(height: 20),
            for (final section in sections) ...[
              Text(
                section.heading,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section.body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
