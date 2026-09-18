import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../feedback/data/model/feedback_model.dart';
import '../../../feedback/data/repository/feedback_repository.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';

/// Public profile of a user: name/photo, how many items they've donated,
/// their overall feedback rating, and the list of feedback they've received.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _profileRepository = ProfileRepository();
  final _postRepository = PostRepository();
  final _feedbackRepository = FeedbackRepository();

  bool _isLoading = true;
  ProfileModel? _profile;
  int _donatedCount = 0;
  List<FeedbackModel> _feedback = const [];
  Map<String, ProfileModel> _reviewerProfiles = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _profileRepository.fetchPublicProfile(widget.userId),
        _postRepository.fetchDonatedCount(widget.userId),
        _feedbackRepository.fetchForUser(widget.userId),
      ]);
      final profile = results[0] as ProfileModel?;
      final donatedCount = results[1] as int;
      final feedback = results[2] as List<FeedbackModel>;

      final reviewerIds = feedback.map((f) => f.fromUserId).toSet().toList();
      final reviewerProfiles = await _profileRepository.fetchPublicProfiles(
        reviewerIds,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _donatedCount = donatedCount;
        _feedback = feedback;
        _reviewerProfiles = reviewerProfiles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _averageRating {
    if (_feedback.isEmpty) return 0;
    final total = _feedback.fold<int>(0, (sum, f) => sum + f.rating);
    return total / _feedback.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const _UserProfileShimmer()
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Column(
                      children: [
                        AppAvatar(radius: 44, imageUrl: _profile?.avatarUrl),
                        const SizedBox(height: 12),
                        Text(
                          _profile?.fullName ?? 'PAO User',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          value: '$_donatedCount',
                          label: 'Donated',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          value: _feedback.isEmpty
                              ? '—'
                              : _averageRating.toStringAsFixed(1),
                          label: _feedback.isEmpty
                              ? 'No ratings'
                              : '${_feedback.length} review${_feedback.length == 1 ? '' : 's'}',
                          icon: _feedback.isEmpty ? null : Icons.star_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Feedback',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_feedback.isEmpty)
                    Text(
                      'No feedback yet.',
                      style: TextStyle(color: context.appTextSecondary),
                    )
                  else
                    for (var i = 0; i < _feedback.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _FeedbackTile(
                        feedback: _feedback[i],
                        reviewer: _reviewerProfiles[_feedback[i].fromUserId],
                      ),
                    ],
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;

  const _StatCard({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: const Color(0xFFFFB020)),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  final FeedbackModel feedback;
  final ProfileModel? reviewer;

  const _FeedbackTile({required this.feedback, required this.reviewer});

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(radius: 16, imageUrl: reviewer?.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reviewer?.fullName ?? 'PAO User',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              Text(
                _timeAgo(feedback.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < feedback.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 16,
                color: const Color(0xFFFFB020),
              );
            }),
          ),
          if (feedback.comment != null && feedback.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              feedback.comment!,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserProfileShimmer extends StatelessWidget {
  const _UserProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: Column(
            children: [
              AppShimmer(
                width: 88,
                height: 88,
                borderRadius: BorderRadius.all(Radius.circular(44)),
              ),
              SizedBox(height: 12),
              AppShimmer(
                width: 140,
                height: 18,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(
              child: AppShimmer(
                height: 70,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: AppShimmer(
                height: 70,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const AppShimmer(
          width: 90,
          height: 14,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          const AppShimmer(
            height: 80,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ],
      ],
    );
  }
}
