import 'package:flutter/material.dart';
import 'legal_document_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Terms & Conditions',
      lastUpdated: 'September 18, 2026',
      sections: [
        LegalSection(
          '1. Acceptance of Terms',
          'By creating an account or using the PAO app, you agree to be bound '
              'by these Terms & Conditions. If you do not agree with any part '
              'of these terms, please do not use the app.',
        ),
        LegalSection(
          '2. Your Account',
          'You must provide accurate information when creating your profile '
              'and are responsible for keeping your login credentials secure. '
              'You are responsible for all activity that happens under your '
              'account.',
        ),
        LegalSection(
          '3. Listings & Requests',
          'When you add an item, post a request, or interact with listings, '
              'you agree that the information you provide is accurate, '
              'truthful, and does not violate any law or the rights of others. '
              'PAO may remove any listing or request that violates these '
              'terms.',
        ),
        LegalSection(
          '4. Role of PAO',
          'PAO provides a platform that connects users to browse listings, '
              'send requests, and chat with one another. PAO is not a party to '
              'any agreement, transaction, or exchange between users and does '
              'not guarantee the accuracy, quality, safety, or legality of any '
              'listing or the conduct of any user.',
        ),
        LegalSection(
          '5. Chat & Communication',
          'The in-app chat is provided to help users communicate about '
              'listings and requests. You agree not to use chat to send '
              'abusive, fraudulent, or unlawful content. Messages may be '
              'stored to provide and improve the service.',
        ),
        LegalSection(
          '6. Wishlist & Personalization',
          'Features such as Wishlist and location-based browsing are provided '
              'for your convenience and are tied to your account. This data '
              'may be used to personalize what you see in the app.',
        ),
        LegalSection(
          '7. Account Deletion',
          'You may delete your account at any time from Settings. Deleting '
              'your account will permanently remove your profile and '
              'associated data, as described in our Privacy Policy, and this '
              'action cannot be undone.',
        ),
        LegalSection(
          '8. Prohibited Conduct',
          'You agree not to misuse the app, including but not limited to: '
              'posting illegal or misleading listings, harassing other users, '
              'attempting to access accounts that are not yours, or '
              'interfering with the normal operation of the app.',
        ),
        LegalSection(
          '9. Limitation of Liability',
          'PAO is provided on an "as is" basis. To the fullest extent '
              'permitted by law, PAO and its team are not liable for any '
              'indirect, incidental, or consequential damages arising from '
              'your use of the app or your interactions with other users.',
        ),
        LegalSection(
          '10. Changes to These Terms',
          'We may update these Terms & Conditions from time to time. '
              'Continued use of the app after changes are published means you '
              'accept the updated terms.',
        ),
        LegalSection(
          '11. Contact Us',
          'If you have questions about these Terms & Conditions, please '
              'reach out through the Help Center in Settings.',
        ),
      ],
    );
  }
}
