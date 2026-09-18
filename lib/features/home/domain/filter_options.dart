import 'product.dart';

const List<String> kSortOptions = ['Newest'];

const List<String> kConditionFilters = ['All', ...kProductConditions];

class FilterOptions {
  final String sortBy;
  final String condition;
  final String category;

  const FilterOptions({
    this.sortBy = 'Newest',
    this.condition = 'All',
    this.category = 'All',
  });

  FilterOptions copyWith({
    String? sortBy,
    String? condition,
    String? category,
  }) {
    return FilterOptions(
      sortBy: sortBy ?? this.sortBy,
      condition: condition ?? this.condition,
      category: category ?? this.category,
    );
  }

  int get activeCount =>
      (sortBy != 'Newest' ? 1 : 0) +
      (condition != 'All' ? 1 : 0) +
      (category != 'All' ? 1 : 0);
}
