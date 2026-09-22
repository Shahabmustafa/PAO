import '../../../core/theme/app_icons.dart';
import '../../../l10n/app_localizations.dart';

/// What a user is sending from Settings > Bugs & Features. The screen builds
/// its type picker from [ReportType.values], so adding a kind of report is
/// one new value here (plus its strings, and the `type` check in
/// `supabase/app_reports_table.sql`).
enum ReportType {
  bug('bug', AppIcons.bug),
  feature('feature', AppIcons.lightbulb);

  const ReportType(this.dbValue, this.icon);

  /// Stored in `app_reports.type`.
  final String dbValue;
  final String icon;

  static ReportType fromDb(String? value) => ReportType.values.firstWhere(
    (t) => t.dbValue == value,
    orElse: () => ReportType.bug,
  );

  String label(AppLocalizations l10n) => switch (this) {
    ReportType.bug => l10n.reportTypeBug,
    ReportType.feature => l10n.reportTypeFeature,
  };

  String caption(AppLocalizations l10n) => switch (this) {
    ReportType.bug => l10n.reportTypeBugCaption,
    ReportType.feature => l10n.reportTypeFeatureCaption,
  };

  String titleLabel(AppLocalizations l10n) => switch (this) {
    ReportType.bug => l10n.reportBugTitleLabel,
    ReportType.feature => l10n.reportFeatureTitleLabel,
  };

  String titleHint(AppLocalizations l10n) => switch (this) {
    ReportType.bug => l10n.reportBugTitleHint,
    ReportType.feature => l10n.reportFeatureTitleHint,
  };

  String descriptionHint(AppLocalizations l10n) => switch (this) {
    ReportType.bug => l10n.reportBugDescriptionHint,
    ReportType.feature => l10n.reportFeatureDescriptionHint,
  };
}

/// Where a report is, as set from the Supabase dashboard.
enum ReportStatus {
  open('open'),
  inProgress('in_progress'),
  done('done'),
  closed('closed');

  const ReportStatus(this.dbValue);

  final String dbValue;

  static ReportStatus fromDb(String? value) => ReportStatus.values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => ReportStatus.open,
  );

  String label(AppLocalizations l10n) => switch (this) {
    ReportStatus.open => l10n.reportStatusOpen,
    ReportStatus.inProgress => l10n.reportStatusInProgress,
    ReportStatus.done => l10n.reportStatusDone,
    ReportStatus.closed => l10n.reportStatusClosed,
  };
}
