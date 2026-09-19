import '../../../l10n/app_localizations.dart';

/// Display labels for the values the app stores in English (product
/// categories, conditions and sort options). The stored value is never
/// translated — only what the user sees.
String categoryLabel(AppLocalizations l10n, String category) {
  switch (category) {
    case 'All':
      return l10n.categoryAll;
    case 'Electronics':
      return l10n.categoryElectronics;
    case 'Fashion':
      return l10n.categoryFashion;
    case 'Home & Living':
      return l10n.categoryHomeLiving;
    case 'Beauty':
      return l10n.categoryBeauty;
    case 'Sports':
      return l10n.categorySports;
    case 'Books':
      return l10n.categoryBooks;
    case 'Toys':
      return l10n.categoryToys;
    case 'Other':
      return l10n.categoryOther;
    default:
      return category;
  }
}

String conditionLabel(AppLocalizations l10n, String condition) {
  switch (condition) {
    case 'All':
      return l10n.categoryAll;
    case 'New':
      return l10n.conditionNew;
    case 'Old':
      return l10n.conditionOld;
    default:
      return condition;
  }
}

String sortLabel(AppLocalizations l10n, String sort) {
  switch (sort) {
    case 'Newest':
      return l10n.sortNewest;
    default:
      return sort;
  }
}
