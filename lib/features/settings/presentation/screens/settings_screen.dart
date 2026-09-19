import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/legal_links.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../../requests/data/request_store.dart';
import '../../../wishlist/data/wishlist_store.dart';
import '../../../wishlist/presentation/screens/wishlist_screen.dart';
import '../../data/language_store.dart';
import '../../domain/app_language.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'language_screen.dart';
import 'theme_screen.dart';
import '../../../../core/l10n/l10n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authRepository = AuthRepository();

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteAccount),
        content: Text(context.l10n.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.l10n.delete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _authRepository.deleteAccount();
      WishlistStore.items.value = [];
      RequestStore.reset();
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pop(context);
      AppSnackbar.show(
        context,
        context.l10n.failedToDeleteAccount,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  String _themeModeLabel(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return context.l10n.themeLight;
      case ThemeMode.dark:
        return context.l10n.themeDark;
      case ThemeMode.system:
        return context.l10n.themeSystem;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.settings,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsCard(
                children: [
                  Padding(
                    padding: EdgeInsets.zero,
                    child: StreamBuilder<AuthState>(
                      stream: _authRepository.authStateChanges,
                      builder: (context, _) {
                        final currentUser = _authRepository.currentUser;
                        return InkWell(
                          onTap: currentUser == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(
                                      userId: currentUser.id,
                                    ),
                                  ),
                                ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                AppAvatar(
                                  radius: 30,
                                  imageUrl: currentUser?.avatarUrl,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentUser?.fullName ??
                                            context.l10n.yourName,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: context.appTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currentUser?.email ??
                                            'your.email@example.com',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: context.appTextSecondary,
                                        ),
                                      ),
                                      if (currentUser != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          context.l10n.viewMyProfile,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (currentUser != null)
                                  const AppIcon(
                                    AppIcons.chevronRight,
                                    mirrorInRtl: true,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsSectionLabel(context.l10n.sectionGeneral),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: AppIcons.person,
                    label: context.l10n.editProfile,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  _SettingsTile(
                    icon: AppIcons.favoriteOutline,
                    label: context.l10n.wishlist,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WishlistScreen(),
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<AppLanguage>(
                    valueListenable: LanguageStore.selected,
                    builder: (context, language, _) {
                      return _SettingsTile(
                        icon: AppIcons.language,
                        label: context.l10n.language,
                        value: language.nativeName,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LanguageScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.themeMode,
                    builder: (context, mode, _) {
                      return _SettingsTile(
                        icon: AppIcons.darkMode,
                        label: context.l10n.theme,
                        value: _themeModeLabel(context, mode),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ThemeScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            _SettingsSectionLabel(context.l10n.sectionLegal),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: AppIcons.description,
                    label: context.l10n.termsAndConditions,
                    onTap: () => LegalLinks.openTerms(context),
                  ),
                  _SettingsTile(
                    icon: AppIcons.privacyTip,
                    label: context.l10n.privacyPolicy,
                    onTap: () => LegalLinks.openPrivacyPolicy(context),
                  ),
                ],
              ),
            ),
            _SettingsSectionLabel(context.l10n.sectionSupport),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: AppIcons.help,
                    label: context.l10n.helpCenter,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpCenterScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: AppIcons.info,
                    label: context.l10n.about,
                    value: 'v1.0.0',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: AppIcons.logout,
                    label: context.l10n.logout,
                    iconColor: AppColors.error,
                    labelColor: AppColors.error,
                    onTap: () async {
                      await _authRepository.logout();
                      WishlistStore.items.value = [];
                      RequestStore.reset();
                      if (!context.mounted) return;
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.login,
                        (route) => false,
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: AppIcons.delete,
                    label: context.l10n.deleteAccount,
                    iconColor: AppColors.error,
                    labelColor: AppColors.error,
                    onTap: () => _confirmDeleteAccount(context),
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

class _SettingsSectionLabel extends StatelessWidget {
  final String label;

  const _SettingsSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.appTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: context.appBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final String? value;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: AppIcon(icon, color: iconColor ?? AppColors.primary),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: labelColor ?? context.appTextPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(
              value!,
              style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            ),
            const SizedBox(width: 6),
          ],
          const AppIcon(
            AppIcons.chevronRight,
            mirrorInRtl: true,
            size: 20,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
