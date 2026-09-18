import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/category.dart';
import '../../domain/filter_options.dart';

/// Shows the filter bottom sheet and returns the chosen [FilterOptions],
/// or null if the sheet was dismissed without applying.
Future<FilterOptions?> showFilterBottomSheet(
  BuildContext context, {
  required FilterOptions initial,
}) {
  return showModalBottomSheet<FilterOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FilterBottomSheet(initial: initial),
  );
}

class _FilterBottomSheet extends StatefulWidget {
  final FilterOptions initial;

  const _FilterBottomSheet({required this.initial});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _sortBy;
  late String _condition;
  late String _category;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initial.sortBy;
    _condition = widget.initial.condition;
    _category = widget.initial.category;
  }

  void _onReset() {
    setState(() {
      _sortBy = 'Newest';
      _condition = 'All';
      _category = 'All';
    });
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const AppIcon(
                  AppIcons.close,
                  size: 20,
                  color: AppColors.primary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kHomeCategories.map((option) {
                      final selected = option == _category;
                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = option),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sort By',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kSortOptions.map((option) {
                      final selected = option == _sortBy;
                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (_) => setState(() => _sortBy = option),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Condition',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kConditionFilters.map((option) {
                      final selected = option == _condition;
                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (_) => setState(() => _condition = option),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onReset,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: BorderSide(color: context.appBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Reset',
                    style: TextStyle(color: context.appTextPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Apply',
                  onPressed: () {
                    Navigator.pop(
                      context,
                      FilterOptions(
                        sortBy: _sortBy,
                        condition: _condition,
                        category: _category,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
