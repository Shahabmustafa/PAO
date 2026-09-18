import 'dart:typed_data';
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

    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _images[index] = bytes);
  }

  void _onRemoveImage(int index) {
    setState(() => _images[index] = null);
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      AppSnackbar.show(
        context,
        'Please select a category',
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
        provider.errorMessage ?? 'Failed to post item.',
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
    AppSnackbar.show(context, 'Product posted for free giveaway');
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<AddItemProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Product',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                const Text(
                  'Give something away for free',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Books, electronics, or anything else someone could use',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Photos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                  label: 'Title',
                  hint: 'e.g. Wireless Headphones',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Describe the item and its condition',
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                          label: Text(category),
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
                            color: selected ? AppColors.onPrimary : AppColors.primary,
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
                const Text(
                  'Condition',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: kProductConditions.map((condition) {
                    final selected = condition == _condition;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(condition),
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
                          color: selected ? AppColors.onPrimary : AppColors.primary,
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
                  label: 'Post for Free',
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
          const Text(
            'Add Photo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ImageSourceOption(
                  icon: AppIcons.camera,
                  label: 'Camera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImageSourceOption(
                  icon: null,
                  materialIcon: Icons.photo_library_outlined,
                  label: 'Gallery',
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
                  Positioned(
                    top: 6,
                    right: 6,
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
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(
                      AppIcons.camera,
                      size: 24,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add Photo',
                      style: TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
