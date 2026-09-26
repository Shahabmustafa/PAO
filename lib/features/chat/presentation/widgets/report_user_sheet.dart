import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

/// Reason codes stored in `user_reports.reason` (see supabase/chat_safety.sql).
const _reasons = ['spam', 'harassment', 'scam', 'inappropriate', 'other'];

String _reasonLabel(BuildContext context, String reason) {
  final l10n = context.l10n;
  return switch (reason) {
    'spam' => l10n.reportReasonSpam,
    'harassment' => l10n.reportReasonHarassment,
    'scam' => l10n.reportReasonScam,
    'inappropriate' => l10n.reportReasonInappropriate,
    _ => l10n.reportReasonOther,
  };
}

/// Bottom sheet to report a user. [onSubmit] returns null on success, or an
/// error message to show. Resolves to true once a report was sent.
Future<bool?> showReportUserSheet(
  BuildContext context, {
  required String userName,
  required Future<String?> Function(String reason, String? details) onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportSheet(userName: userName, onSubmit: onSubmit),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.userName, required this.onSubmit});

  final String userName;
  final Future<String?> Function(String reason, String? details) onSubmit;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final text = _details.text.trim();
    final error = await widget.onSubmit(reason, text.isEmpty ? null : text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.reportUserTitle(widget.userName),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.reportUserSubtitle,
              style: TextStyle(color: context.appTextSecondary),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in _reasons)
                    RadioListTile<String>(
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: Text(_reasonLabel(context, reason)),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: context.l10n.reportDetailsHint,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: context.l10n.submit,
              isLoading: _submitting,
              onPressed: _reason == null || _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
