import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/model/report_model.dart';
import '../../domain/report_type.dart';
import '../provider/report_provider.dart';
import '../../../../core/l10n/l10n.dart';

/// Settings > Bugs & Features: send a bug report or a feature idea, and see
/// what you've sent before along with its status.
class ReportScreen extends StatelessWidget {
  final ReportProvider? provider;

  const ReportScreen({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (provider ?? ReportProvider())..loadReports(),
      child: const _ReportView(),
    );
  }
}

class _ReportView extends StatefulWidget {
  const _ReportView();

  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ReportProvider>();
    final success = await provider.submit(
      title: _titleController.text,
      description: _descriptionController.text,
    );
    if (!context.mounted) return;
    if (success) {
      _titleController.clear();
      _descriptionController.clear();
      AppSnackbar.show(context, context.l10n.reportSubmitted);
    } else {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToSubmitReport,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final l10n = context.l10n;
    final type = provider.type;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.bugsAndFeatures,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.loadReports,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                l10n.reportsIntro,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final option in ReportType.values) ...[
                    if (option != ReportType.values.first)
                      const SizedBox(width: 12),
                    Expanded(
                      child: _TypeCard(
                        type: option,
                        selected: option == type,
                        onTap: () => provider.selectType(option),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _titleController,
                      label: type.titleLabel(l10n),
                      hint: type.titleHint(l10n),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? l10n.reportTitleRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descriptionController,
                      label: l10n.reportDetailsLabel,
                      hint: type.descriptionHint(l10n),
                      keyboardType: TextInputType.multiline,
                      maxLines: 5,
                      validator: (value) => (value?.trim().length ?? 0) < 10
                          ? l10n.reportDescriptionTooShort
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: l10n.submit,
                isLoading: provider.isSubmitting,
                onPressed: () => _submit(context),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.myReports,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (provider.isLoadingReports)
                const _ReportListShimmer()
              else if (provider.reports.isEmpty)
                _EmptyReports(
                  text: provider.loadError ?? l10n.noReportsYet,
                  isError: provider.loadError != null,
                )
              else
                _ReportCard(
                  children: [
                    for (var i = 0; i < provider.reports.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          color: context.appBorder,
                        ),
                      _ReportTile(report: provider.reports[i]),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One option of the bug / feature picker.
class _TypeCard extends StatelessWidget {
  final ReportType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : context.appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : context.appBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: type.icon),
              const SizedBox(height: 12),
              Text(
                type.label(context.l10n),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                type.caption(context.l10n),
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final String icon;
  final double size;

  const _IconBadge({required this.icon, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: AppIcon(icon, size: size / 2, color: AppColors.primary),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final List<Widget> children;

  const _ReportCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final ReportModel report;

  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(report.createdAt.toLocal());
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: report.type.icon, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.type.label(l10n)} · $date',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: report.status),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ReportStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ReportStatus.open => AppColors.primaryDark,
      ReportStatus.inProgress => Colors.orange,
      ReportStatus.done => Colors.green,
      ReportStatus.closed => context.appTextSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label(context.l10n),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  final String text;
  final bool isError;

  const _EmptyReports({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isError ? AppColors.error : context.appTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportListShimmer extends StatelessWidget {
  const _ReportListShimmer();

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                AppShimmer(
                  width: 36,
                  height: 36,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmer(
                        height: 12,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      SizedBox(height: 8),
                      AppShimmer(
                        width: 120,
                        height: 10,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
