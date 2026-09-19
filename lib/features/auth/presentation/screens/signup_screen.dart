import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/terms_acceptance_checkbox.dart';
import '../provider/signup_provider.dart';
import '../../../../core/l10n/l10n.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupProvider(),
      child: const _SignupView(),
    );
  }
}

class _SignupView extends StatefulWidget {
  const _SignupView();

  @override
  State<_SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<_SignupView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSignupPressed() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      AppSnackbar.show(
        context,
        context.l10n.acceptTermsToContinue,
        icon: Icons.info_outline,
        color: AppColors.error,
      );
      return;
    }

    final provider = context.read<SignupProvider>();
    final result = await provider.signUp(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;

    switch (result) {
      case SignupResult.success:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboard,
          (route) => false,
        );
      case SignupResult.needsEmailConfirmation:
        AppSnackbar.show(
          context,
          context.l10n.checkEmailToConfirm,
          icon: Icons.mark_email_read_outlined,
        );
        Navigator.pop(context);
      case SignupResult.failure:
        if (provider.errorMessage != null) {
          AppSnackbar.show(
            context,
            provider.errorMessage!,
            icon: Icons.error_outline,
            color: AppColors.error,
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<SignupProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.createAccount,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.signUpToGetStarted,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                CustomTextField(
                  controller: _nameController,
                  label: context.l10n.fullName,
                  hint: context.l10n.enterFullName,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.nameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _emailController,
                  label: context.l10n.email,
                  hint: context.l10n.enterYourEmail,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.emailRequired;
                    }
                    if (!value.contains('@')) {
                      return context.l10n.enterValidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _passwordController,
                  label: context.l10n.password,
                  hint: context.l10n.createPasswordHint,
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
                  controller: _confirmPasswordController,
                  label: context.l10n.confirmPassword,
                  hint: context.l10n.reenterPassword,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: AppIcon(
                      _obscureConfirmPassword
                          ? AppIcons.visibilityOff
                          : AppIcons.visibility,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return context.l10n.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TermsAcceptanceCheckbox(
                  value: _acceptedTerms,
                  onChanged: (value) {
                    setState(() => _acceptedTerms = value);
                  },
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: context.l10n.signUp,
                  isLoading: isLoading,
                  onPressed: _onSignupPressed,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.haveAccountPrompt,
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        context.l10n.login,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
