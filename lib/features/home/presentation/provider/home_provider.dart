import 'package:flutter/foundation.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../data/product_store.dart';
import '../../domain/category.dart';
import '../../domain/filter_options.dart';
import '../../domain/product.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository() {
    ProductStore.startRealtimeSync();
    refresh();
  }

  final AuthRepository _authRepository;

  String selectedCategory = kHomeCategories.first;
  FilterOptions filters = const FilterOptions();
  String searchQuery = '';

  Future<void> refresh() => ProductStore.syncFromSupabase().catchError((_) {});

  void onSearchChanged(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void applyFilters(FilterOptions result) {
    filters = result;
    selectedCategory = result.category;
    notifyListeners();
  }

  bool get hasActiveSearch =>
      searchQuery.trim().isNotEmpty ||
      selectedCategory != kHomeCategories.first ||
      filters.activeCount > 0;

  void clearSearch() {
    searchQuery = '';
    filters = const FilterOptions();
    selectedCategory = kHomeCategories.first;
    notifyListeners();
  }

  List<Product> filterProducts(List<Product> source) {
    final query = searchQuery.trim().toLowerCase();
    final currentUserId = _authRepository.currentUser?.id;
    return source.where((product) {
      if (product.isGiven) return false;
      if (currentUserId != null && product.userId == currentUserId) {
        return false;
      }
      final matchesCategory =
          selectedCategory == 'All' || product.category == selectedCategory;
      final matchesSearch =
          query.isEmpty || product.name.toLowerCase().contains(query);
      final matchesCondition =
          filters.condition == 'All' || product.condition == filters.condition;
      return matchesCategory && matchesSearch && matchesCondition;
    }).toList();
  }
}
