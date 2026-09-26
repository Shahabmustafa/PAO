import '../../../core/l10n/l10n.dart';

class AppRelease {
  final String version;
  final DateTime date;
  final List<String> Function(AppLocalizations l10n) changes;

  const AppRelease(this.version, this.date, this.changes);
}

/// Newest first.
final List<AppRelease> appReleases = [
  AppRelease(
    '1.5.2',
    DateTime(2026, 9, 26),
    (l) => [l.c152a, l.c152b, l.c152c, l.c152d],
  ),
  AppRelease(
    '1.5.0',
    DateTime(2026, 9, 24),
    (l) => [l.c150a, l.c150b, l.c150c, l.c150d],
  ),
  AppRelease(
    '1.4.0',
    DateTime(2026, 9, 23),
    (l) => [l.c140a, l.c140b, l.c140c, l.c140d, l.c140e],
  ),
  AppRelease(
    '1.2.0',
    DateTime(2026, 9, 22),
    (l) => [l.c120a, l.c120b, l.c120c],
  ),
  AppRelease(
    '1.1.1',
    DateTime(2026, 9, 22),
    (l) => [l.c111a, l.c111b, l.c111c],
  ),
  AppRelease(
    '1.1.0',
    DateTime(2026, 9, 19),
    (l) => [l.c110a, l.c110b, l.c110c, l.c110d],
  ),
  AppRelease('1.0.0', DateTime(2026, 9, 18), (l) => [l.c100a, l.c100b]),
];
