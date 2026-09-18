import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../requests/data/request_store.dart';
import '../../../wishlist/data/wishlist_store.dart';
import '../../../wishlist/presentation/screens/wishlist_screen.dart';
import '../../data/language_store.dart';
import '../../domain/app_language.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'language_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'theme_screen.dart';

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
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
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
        'Failed to delete account. Please try again.',
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                    padding: const EdgeInsets.all(16),
                    child: StreamBuilder<AuthState>(
                      stream: _authRepository.authStateChanges,
                      builder: (context, _) {
                        final currentUser = _authRepository.currentUser;
                        return Row(
                          children: [
                            AppAvatar(
                              radius: 30,
                              imageUrl: currentUser?.avatarUrl,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentUser?.fullName ?? 'Your Name',
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
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SettingsSectionLabel('General'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: AppIcons.person,
                    label: 'Edit Profile',
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
                    label: 'Wishlist',
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
                        label: 'Language',
                        value: language.name,
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
                        label: 'Theme',
                        value: _themeModeLabel(mode),
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
                  _SettingsTile(
                    icon: AppIcons.lock,
                    label: 'Privacy & Security',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const _SettingsSectionLabel('Legal'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: AppIcons.description,
                    label: 'Terms & Conditions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsConditionsScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: AppIcons.privacyTip,
                    label: 'Privacy Policy',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const _SettingsSectionLabel('Support'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: AppIcons.help,
                    label: 'Help Center',
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
                    label: 'About',
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
                    label: 'Logout',
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
                    label: 'Delete Account',
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
            if (i > 0)
              Divider(height: 1, indent: 56, color: context.appBorder),
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
            size: 20,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
