import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/data/product_store.dart';
import '../../../home/domain/category.dart';
import '../../../home/domain/product.dart';
import '../provider/add_item_provider.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../home/domain/localized_labels.dart';

class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddItemProvider(),
      child: const _AddItemView(),
    );
  }
}

class _AddItemView extends StatefulWidget {
  const _AddItemView();

  @override
  State<_AddItemView> createState() => _AddItemViewState();
}

class _AddItemViewState extends State<_AddItemView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  final List<Uint8List?> _images = [null, null];
  String? _selectedCategory;
  String _condition = 'New';

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _onPickImage(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ImageSourceSheet(),
    );
    if (source == null) return;

    // Cap the resolution: a full-size camera photo is decoded and
    // re-encoded in memory, which gets the app killed on low-RAM devices.
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _images[index] = bytes);
  }

  // Android may kill the app while the camera is open; the photo is then
  // delivered on the next launch through retrieveLostData.
  Future<void> _recoverLostImage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final response = await _picker.retrieveLostData();
    if (response.isEmpty || response.file == null) return;
    final bytes = await response.file!.readAsBytes();
    if (!mounted) return;
    final slot = _images.indexWhere((image) => image == null);
    setState(() => _images[slot == -1 ? 0 : slot] = bytes);
  }

  void _onRemoveImage(int index) {
    setState(() => _images[index] = null);
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      AppSnackbar.show(
        context,
        context.l10n.pleaseSelectCategory,
        icon: Icons.info_outline,
        color: AppColors.error,
      );
      return;
    }

    final images = _images.whereType<Uint8List>().toList();
    final provider = context.read<AddItemProvider>();
    final post = await provider.submit(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory!,
      condition: _condition,
      images: images,
    );
    if (!mounted) return;

    if (post == null) {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToPostItem,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
      return;
    }

    ProductStore.add(
      Product(
        id: post.id,
        name: _titleController.text.trim(),
        category: _selectedCategory!,
        color: AppColors.primary,
        description: _descriptionController.text.trim(),
        condition: _condition,
        images: images,
        imageUrls: post.imageUrls,
        userId: post.userId,
      ),
    );

    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _images[0] = null;
      _images[1] = null;
      _selectedCategory = null;
      _condition = 'New';
    });

    if (!mounted) return;
    AppSnackbar.show(context, context.l10n.productPosted);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<AddItemProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.addProduct,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.giveSomethingAway,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.addItemSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.photos,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < 2; i++) ...[
                      _ImageSlot(
                        image: _images[i],
                        onTap: () => _onPickImage(i),
                        onRemove: () => _onRemoveImage(i),
                      ),
                      if (i == 0) const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _titleController,
                  label: context.l10n.title,
                  hint: context.l10n.titleHint,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.titleRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _descriptionController,
                  label: context.l10n.description,
                  hint: context.l10n.describeItemHint,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.descriptionRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kHomeCategories
                      .where((category) => category != 'All')
                      .map((category) {
                        final selected = category == _selectedCategory;
                        return ChoiceChip(
                          label: Text(categoryLabel(context.l10n, category)),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _selectedCategory = category);
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.08,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? AppColors.onPrimary
                                : context.appTextPrimary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none,
                          ),
                          showCheckmark: false,
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.condition,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: kProductConditions.map((condition) {
                    final selected = condition == _condition;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: ChoiceChip(
                        label: Text(conditionLabel(context.l10n, condition)),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _condition = condition),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.onPrimary
                              : context.appTextPrimary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: context.l10n.postForFree,
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

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.addPhoto,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ImageSourceOption(
                  icon: AppIcons.camera,
                  label: context.l10n.camera,
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImageSourceOption(
                  icon: null,
                  materialIcon: Icons.photo_library_outlined,
                  label: context.l10n.gallery,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  final String? icon;
  final IconData? materialIcon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.materialIcon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            icon != null
                ? AppIcon(icon!, size: 24, color: AppColors.primary)
                : Icon(materialIcon, size: 24, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  final Uint8List? image;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ImageSlot({
    required this.image,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: image == null ? onTap : null,
      child: Container(
        height: 110,
        width: 110,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: image != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(image!, fit: BoxFit.cover),
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        height: 24,
                        width: 24,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const AppIcon(
                          AppIcons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppIcon(
                      AppIcons.camera,
                      size: 24,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.addPhoto,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
