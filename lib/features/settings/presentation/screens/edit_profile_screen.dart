import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../provider/edit_profile_provider.dart';
import '../../../../core/l10n/l10n.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditProfileProvider(),
      child: const _EditProfileView(),
    );
  }
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView();

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final currentUser = AuthRepository().currentUser;
    _nameController.text = currentUser?.fullName ?? '';
    _emailController.text = currentUser?.email ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final profile = await context.read<EditProfileProvider>().loadProfile();
    if (!mounted || profile == null) return;
    setState(() {
      if (profile.fullName != null) _nameController.text = profile.fullName!;
      if (profile.email != null) _emailController.text = profile.email!;
      _phoneController.text = profile.phone ?? '';
      _bioController.text = profile.bio ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _onPickAvatarPressed() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final provider = context.read<EditProfileProvider>();
    await provider.uploadAvatar(bytes);
    if (!mounted) return;

    if (provider.errorMessage != null) {
      AppSnackbar.show(
        context,
        provider.errorMessage!,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<EditProfileProvider>();
    final success = await provider.save(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
    );
    if (!mounted) return;

    if (!success) {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToUpdateProfile,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
      return;
    }

    AppSnackbar.show(
      context,
      provider.emailChangeNeedsConfirmation
          ? context.l10n.profileUpdatedConfirmEmail
          : context.l10n.profileUpdated,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditProfileProvider>();
    final isLoading = provider.isLoading;
    final isSaving = provider.isSaving;
    final isUploadingAvatar = provider.isUploadingAvatar;
    final avatarUrl = provider.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.editProfile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const _EditProfileShimmer()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: AppColors.primary,
                              backgroundImage: avatarUrl != null
                                  ? CachedNetworkImageProvider(avatarUrl)
                                        as ImageProvider
                                  : const AssetImage(
                                      'assets/images/profile.jpg',
                                    ),
                              child: isUploadingAvatar
                                  ? const CircularProgressIndicator(
                                      color: AppColors.onPrimary,
                                    )
                                  : null,
                            ),
                            PositionedDirectional(
                              bottom: 0,
                              end: 0,
                              child: Container(
                                height: 32,
                                width: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    width: 2,
                                  ),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const AppIcon(
                                    AppIcons.camera,
                                    size: 16,
                                    color: AppColors.onPrimary,
                                  ),
                                  onPressed: isUploadingAvatar
                                      ? null
                                      : _onPickAvatarPressed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomTextField(
                        controller: _nameController,
                        label: context.l10n.fullName,
                        hint: context.l10n.enterFullName,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
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
                        controller: _phoneController,
                        label: context.l10n.phoneOptional,
                        hint: context.l10n.enterPhoneHint,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 18),
                      CustomTextField(
                        controller: _bioController,
                        label: context.l10n.bioOptional,
                        hint: context.l10n.bioHint,
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: context.l10n.saveChanges,
                        isLoading: isSaving,
                        onPressed: _onSavePressed,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _EditProfileShimmer extends StatelessWidget {
  const _EditProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Center(
            child: AppShimmer(
              width: 92,
              height: 92,
              borderRadius: BorderRadius.all(Radius.circular(46)),
            ),
          ),
          SizedBox(height: 32),
          _FieldShimmer(),
          SizedBox(height: 18),
          _FieldShimmer(),
          SizedBox(height: 18),
          _FieldShimmer(),
          SizedBox(height: 18),
          _FieldShimmer(),
        ],
      ),
    );
  }
}

class _FieldShimmer extends StatelessWidget {
  const _FieldShimmer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmer(
          width: 80,
          height: 12,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        SizedBox(height: 8),
        AppShimmer(
          width: double.infinity,
          height: 48,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ],
    );
  }
}
