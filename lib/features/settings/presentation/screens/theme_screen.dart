import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/l10n/l10n.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  static const _options = [
    (mode: ThemeMode.light, icon: AppIcons.lightMode),
    (mode: ThemeMode.dark, icon: AppIcons.darkMode),
    (mode: ThemeMode.system, icon: AppIcons.settingsSuggest),
  ];

  static String _title(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return context.l10n.themeLight;
      case ThemeMode.dark:
        return context.l10n.themeDark;
      case ThemeMode.system:
        return context.l10n.themeSystem;
    }
  }

  static String _subtitle(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return context.l10n.themeLightSubtitle;
      case ThemeMode.dark:
        return context.l10n.themeDarkSubtitle;
      case ThemeMode.system:
        return context.l10n.themeSystemSubtitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.theme,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.themeMode,
          builder: (context, currentMode, _) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  context.l10n.chooseHowPaoLooks,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final option in _options) ...[
                  _ThemeOptionCard(
                    icon: option.icon,
                    title: _title(context, option.mode),
                    subtitle: _subtitle(context, option.mode),
                    selected: currentMode == option.mode,
                    onTap: () => ThemeController.setThemeMode(option.mode),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: AppIcon(icon, color: AppColors.primary)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppIcon(
              selected ? AppIcons.radioChecked : AppIcons.radioUnchecked,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
