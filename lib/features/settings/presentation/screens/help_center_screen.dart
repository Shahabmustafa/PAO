import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';

class _Faq {
  final String question;
  final String answer;

  const _Faq(this.question, this.answer);
}

const _faqs = [
  _Faq(
    'How do I give away an item?',
    'Tap the purple + button on the home screen, add a few photos, a '
        'title, description, category and condition, then post it. It '
        'will show up in listings right away.',
  ),
  _Faq(
    'How do I request an item?',
    'Open any listing and tap "Give Me". This sends a request to the '
        'owner and lets you chat with them about it.',
  ),
  _Faq(
    'How do I chat with the owner or requester?',
    'Once a request has been sent, open it from the Inbox or tap '
        '"Message Owner" on the listing to start chatting.',
  ),
  _Faq(
    'How do I accept a request for my item?',
    'Open the chat for that request and tap "Accept & Give This Item". '
        'This marks the item as given and closes any other pending '
        'requests on it.',
  ),
  _Faq(
    'How do I save an item to my Wishlist?',
    'Tap the heart icon on any listing. You can find everything you\'ve '
        'saved under Settings > Wishlist.',
  ),
  _Faq(
    'Can I change the app language or theme?',
    'Yes — go to Settings and open Language or Theme to switch between '
        'light, dark, or your device\'s default.',
  ),
  _Faq(
    'How do I edit my profile?',
    'Go to Settings > Edit Profile to update your name, photo, and '
        'other details.',
  ),
  _Faq(
    'How do I delete my account?',
    'Go to Settings > Delete Account. This permanently removes your '
        'profile and data and cannot be undone.',
  ),
  _Faq(
    'Is my data safe?',
    'We only use your information to run the app\'s features. See our '
        'Privacy Policy under Settings > Legal for the full details.',
  ),
];

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Frequently asked questions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _faqs.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 16, color: context.appBorder),
                    _FaqTile(
                      faq: _faqs[i],
                      expanded: _expandedIndex == i,
                      onTap: () {
                        setState(() {
                          _expandedIndex = _expandedIndex == i ? null : i;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Still need help?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appBorder),
              ),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: AppIcon(
                        AppIcons.help,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Can\'t find what you\'re looking for? More ways to '
                      'reach us will show up here soon.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _Faq faq;
  final bool expanded;
  final VoidCallback onTap;

  const _FaqTile({
    required this.faq,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    faq.question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: AppIcon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  faq.answer,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}
