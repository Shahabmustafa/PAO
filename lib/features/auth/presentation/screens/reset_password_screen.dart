import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../provider/reset_password_provider.dart';

/// Shown when the user opens the link from the "reset your password" email.
/// The link signs them in with a temporary session, which is enough to set
/// a new password.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ResetPasswordProvider(),
      child: const _ResetPasswordView(),
    );
  }
}

class _ResetPasswordView extends StatefulWidget {
  const _ResetPasswordView();

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onUpdatePressed() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ResetPasswordProvider>();
    final success = await provider.updatePassword(_passwordController.text);
    if (!mounted) return;

    if (success) {
      AppSnackbar.show(context, context.l10n.passwordUpdated);
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboard,
        (route) => false,
      );
    } else if (provider.errorMessage != null) {
      AppSnackbar.show(
        context,
        provider.errorMessage!,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  Future<void> _onBackToLoginPressed() async {
    await context.read<ResetPasswordProvider>().cancel();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ResetPasswordProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const AppIcon(
                    AppIcons.lockReset,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.resetPasswordTitle,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.resetPasswordSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  controller: _passwordController,
                  label: context.l10n.newPassword,
                  hint: context.l10n.enterNewPassword,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: AppIcon(
                      _obscurePassword
                          ? AppIcons.visibilityOff
                          : AppIcons.visibility,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.passwordRequired;
                    }
                    if (value.length < 6) {
                      return context.l10n.passwordMinLength;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _confirmController,
                  label: context.l10n.confirmPassword,
                  hint: context.l10n.reenterPassword,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: AppIcon(
                      _obscureConfirm
                          ? AppIcons.visibilityOff
                          : AppIcons.visibility,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return context.l10n.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: context.l10n.updatePassword,
                  isLoading: isLoading,
                  onPressed: _onUpdatePressed,
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: isLoading ? null : _onBackToLoginPressed,
                    child: Text(
                      context.l10n.backToLogin,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
