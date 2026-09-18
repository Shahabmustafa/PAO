import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/repository/feedback_repository.dart';

/// Shows a star-rating + comment bottom sheet and submits it to Supabase.
/// Returns `true` if feedback was submitted, `false`/`null` otherwise.
Future<bool?> showFeedbackDialog(
  BuildContext context, {
  required String requestId,
  required String postId,
  required String fromUserId,
  required String toUserId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FeedbackSheet(
      requestId: requestId,
      postId: postId,
      fromUserId: fromUserId,
      toUserId: toUserId,
    ),
  );
}

class _FeedbackSheet extends StatefulWidget {
  final String requestId;
  final String postId;
  final String fromUserId;
  final String toUserId;

  const _FeedbackSheet({
    required this.requestId,
    required this.postId,
    required this.fromUserId,
    required this.toUserId,
  });

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _repository = FeedbackRepository();
  final _commentController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _onSubmitPressed() async {
    if (_rating == 0) {
      setState(() => _errorMessage = 'Please select a rating');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _repository.submit(
        requestId: widget.requestId,
        postId: widget.postId,
        fromUserId: widget.fromUserId,
        toUserId: widget.toUserId,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to submit feedback. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rate this exchange',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = starValue),
                icon: Icon(
                  starValue <= _rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFB020),
                  size: 22,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Leave a comment (optional)',
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Submit',
                  isLoading: _isSubmitting,
                  onPressed: _onSubmitPressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
