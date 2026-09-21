import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/data/product_store.dart';
import '../../../home/domain/category.dart';
import '../../../home/domain/product.dart';
import '../provider/add_item_provider.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../home/domain/localized_labels.dart';

/// The "Add Product" form. Given a [product] it becomes the edit form for that
/// post instead: pre-filled, saving updates the post, and it pops with the
/// updated [Product].
class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key, this.product});

  final Product? product;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddItemProvider(),
      child: _AddItemView(editing: product),
    );
  }
}

/// A photo in one of the form's slots: either one already uploaded (when
/// editing) or one just picked from the camera or gallery.
class _Photo {
  const _Photo.remote(String this.url) : bytes = null;
  const _Photo.picked(Uint8List this.bytes) : url = null;

  final String? url;
  final Uint8List? bytes;
}

class _AddItemView extends StatefulWidget {
  const _AddItemView({this.editing});

  final Product? editing;

  @override
  State<_AddItemView> createState() => _AddItemViewState();
}

class _AddItemViewState extends State<_AddItemView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _picker = ImagePicker();

  final List<_Photo?> _images = [null, null];
  String? _selectedCategory;
  String _condition = 'New';

  Product? get _editing => widget.editing;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    if (editing != null) {
      _titleController.text = editing.name;
      _descriptionController.text = editing.description;
      _addressController.text = editing.address ?? '';
      _selectedCategory = editing.category;
      _condition = editing.condition;
      for (var i = 0; i < _images.length && i < editing.imageUrls.length; i++) {
        _images[i] = _Photo.remote(editing.imageUrls[i]);
      }
    }
    _recoverLostImage();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _onPickImage(int index) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => const _ImageSourceDialog(),
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
    setState(() => _images[index] = _Photo.picked(bytes));
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
    setState(() => _images[slot == -1 ? 0 : slot] = _Photo.picked(bytes));
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

    final editing = _editing;
    if (editing != null) return _saveEdits(editing);

    final images = [for (final photo in _images) ?photo?.bytes];
    final provider = context.read<AddItemProvider>();
    final post = await provider.submit(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory!,
      condition: _condition,
      address: _addressController.text.trim(),
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
        address: _addressController.text.trim(),
        images: images,
        imageUrls: post.imageUrls,
        userId: post.userId,
      ),
    );

    _titleController.clear();
    _descriptionController.clear();
    _addressController.clear();
    setState(() {
      _images[0] = null;
      _images[1] = null;
      _selectedCategory = null;
      _condition = 'New';
    });

    if (!mounted) return;
    AppSnackbar.show(context, context.l10n.productPosted);
  }

  Future<void> _saveEdits(Product editing) async {
    final kept = [for (final photo in _images) ?photo?.url];
    final provider = context.read<AddItemProvider>();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final address = _addressController.text.trim();
    final post = await provider.update(
      postId: editing.id,
      title: title,
      description: description,
      category: _selectedCategory!,
      condition: _condition,
      address: address,
      keptImageUrls: kept,
      newImages: [for (final photo in _images) ?photo?.bytes],
      removedImageUrls: [
        for (final url in editing.imageUrls)
          if (!kept.contains(url)) url,
      ],
    );
    if (!mounted) return;

    if (post == null) {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToUpdate,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
      return;
    }

    final updated = ProductStore.productFromPost(post);
    ProductStore.update(updated);
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<AddItemProvider>().isLoading;
    final photoCount = _images.whereType<_Photo>().length;
    final isEditing = _editing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? context.l10n.editProduct : context.l10n.addProduct,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                  context.l10n.photos,
                  trailing: '$photoCount/${_images.length}',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < _images.length; i++) ...[
                      Expanded(
                        child: _ImageSlot(
                          image: _images[i],
                          onTap: () => _onPickImage(i),
                          onRemove: () => _onRemoveImage(i),
                        ),
                      ),
                      if (i < _images.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
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
                CustomTextField(
                  controller: _addressController,
                  label: context.l10n.address,
                  hint: context.l10n.enterAddressHint,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.addressRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _SectionLabel(context.l10n.category),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kHomeCategories
                      .where((category) => category != 'All')
                      .map(
                        (category) => _OptionChip(
                          label: categoryLabel(context.l10n, category),
                          icon: _categoryIcons[category],
                          selected: category == _selectedCategory,
                          onSelected: () =>
                              setState(() => _selectedCategory = category),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                _SectionLabel(context.l10n.condition),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < kProductConditions.length; i++) ...[
                      Expanded(
                        child: _OptionChip(
                          label: conditionLabel(
                            context.l10n,
                            kProductConditions[i],
                          ),
                          selected: kProductConditions[i] == _condition,
                          onSelected: () => setState(
                            () => _condition = kProductConditions[i],
                          ),
                        ),
                      ),
                      if (i < kProductConditions.length - 1)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: isEditing
                      ? context.l10n.saveChanges
                      : context.l10n.postForFree,
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

const Map<String, IconData> _categoryIcons = {
  'Electronics': Icons.headphones_outlined,
  'Fashion': Icons.checkroom_outlined,
  'Home & Living': Icons.chair_outlined,
  'Beauty': Icons.spa_outlined,
  'Sports': Icons.sports_soccer_outlined,
  'Books': Icons.menu_book_outlined,
  'Toys': Icons.toys_outlined,
  'Other': Icons.category_outlined,
};

class _SectionLabel extends StatelessWidget {
  final String text;
  final String? trailing;

  const _SectionLabel(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
          ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelected;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onPrimary : context.appTextPrimary;
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 18, color: foreground),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: context.appSurface,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: foreground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: selected ? AppColors.primary : context.appBorder,
        ),
      ),
    );
  }
}

class _ImageSourceDialog extends StatelessWidget {
  const _ImageSourceDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(
        context.l10n.addPhoto,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: context.appTextPrimary,
        ),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
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
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.appTextSecondary,
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ],
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
    return Material(
      color: AppColors.primary.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.appBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBadge(
                child: icon != null
                    ? AppIcon(icon!, size: 22, color: AppColors.onPrimary)
                    : Icon(materialIcon, size: 22, color: AppColors.onPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final Widget child;

  const _IconBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

class _ImageSlot extends StatelessWidget {
  static const double _height = 150;
  static const double _radius = 18;

  final _Photo? image;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ImageSlot({
    required this.image,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            color: context.isDarkMode
                ? AppColors.primary.withValues(alpha: 0.6)
                : context.appTextSecondary.withValues(alpha: 0.5),
            radius: _radius,
          ),
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(_radius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _IconBadge(
                  child: AppIcon(
                    AppIcons.camera,
                    size: 22,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.addPhoto,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: context.appBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image!.bytes != null
              ? Image.memory(image!.bytes!, fit: BoxFit.cover)
              : AppNetworkImage(imageUrl: image!.url!),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                height: 28,
                width: 28,
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
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  static const double _dash = 6;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
