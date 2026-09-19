import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/l10n/l10n.dart';

class _Faq {
  final String question;
  final String answer;

  const _Faq(this.question, this.answer);
}

List<_Faq> _buildFaqs(AppLocalizations l10n) => [
  _Faq(l10n.faq1Q, l10n.faq1A),
  _Faq(l10n.faq2Q, l10n.faq2A),
  _Faq(l10n.faq3Q, l10n.faq3A),
  _Faq(l10n.faq4Q, l10n.faq4A),
  _Faq(l10n.faq5Q, l10n.faq5A),
  _Faq(l10n.faq6Q, l10n.faq6A),
  _Faq(l10n.faq7Q, l10n.faq7A),
  _Faq(l10n.faq8Q, l10n.faq8A),
  _Faq(l10n.faq9Q, l10n.faq9A),
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
    final faqs = _buildFaqs(context.l10n);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.helpCenter,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              context.l10n.frequentlyAskedQuestions,
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
                  for (var i = 0; i < faqs.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 16, color: context.appBorder),
                    _FaqTile(
                      faq: faqs[i],
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
              context.l10n.stillNeedHelp,
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
                      context.l10n.cantFindWhatYouNeed,
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
                  turns: expanded
                      ? (Directionality.of(context) == TextDirection.rtl
                            ? -0.25
                            : 0.25)
                      : 0,
                  duration: const Duration(milliseconds: 200),
                  child: AppIcon(
                    AppIcons.chevronRight,
                    mirrorInRtl: true,
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
