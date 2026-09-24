import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/cache/local_cache.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';

class _Donor {
  const _Donor(this.userId, this.count, this.profile);
  final String userId;
  final int count;
  final ProfileModel? profile;
}

/// Everyone who has given at least one item away, most donations first.
class DonorsScreen extends StatefulWidget {
  const DonorsScreen({super.key});

  @override
  State<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends State<DonorsScreen> {
  final _postRepository = PostRepository();
  final _profileRepository = ProfileRepository();

  List<_Donor>? _donors;
  bool _failed = false;

  static const _topCount = 10;
  static const _cacheKey = 'donors';
  static const _maxAge = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    // Paint from Hive at once; only go to Supabase when the copy is stale.
    _donors = _readCache();
    if (_donors == null || !LocalCache.isFresh(_cacheKey, _maxAge)) _load();
  }

  List<_Donor>? _readCache() {
    final rows = LocalCache.readList(LocalCache.profiles, _cacheKey);
    if (rows.isEmpty) return null;
    return [
      for (final r in rows)
        _Donor(
          r['id'] as String,
          (r['count'] as num).toInt(),
          ProfileModel(
            id: r['id'] as String,
            fullName: r['full_name'] as String?,
            avatarUrl: r['avatar_url'] as String?,
          ),
        ),
    ];
  }

  void _writeCache(List<_Donor> donors) {
    LocalCache.write(LocalCache.profiles, _cacheKey, [
      for (final d in donors)
        {
          'id': d.userId,
          'count': d.count,
          'full_name': d.profile?.fullName,
          'avatar_url': d.profile?.avatarUrl,
        },
    ]);
    LocalCache.markSynced(_cacheKey);
  }

  Future<void> _load() async {
    try {
      final counts = await _postRepository.fetchDonorCounts();
      // Only the top donors are shown, so only their profiles are fetched.
      final top =
          (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .take(_topCount)
              .toList();
      final profiles = await _profileRepository.fetchPublicProfiles([
        for (final e in top) e.key,
      ]);
      final donors = [
        for (final e in top) _Donor(e.key, e.value, profiles[e.key]),
      ];
      _writeCache(donors);
      if (!mounted) return;
      setState(() {
        _donors = donors;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = _donors == null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final donors = _donors;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.donorsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: donors == null
            ? Center(
                child: _failed
                    ? TextButton(
                        onPressed: () {
                          setState(() => _failed = false);
                          _load();
                        },
                        child: Text(context.l10n.donorsEmptyHint),
                      )
                    : const CircularProgressIndicator(color: AppColors.primary),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: donors.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * .25,
                          ),
                          _Empty(),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        // Clears the floating nav bar.
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                        itemCount: donors.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _DonorTile(rank: i + 1, donor: donors[i]),
                      ),
              ),
      ),
    );
  }
}

class _DonorTile extends StatelessWidget {
  const _DonorTile({required this.rank, required this.donor});
  final int rank;
  final _Donor donor;

  @override
  Widget build(BuildContext context) {
    final name = donor.profile?.fullName;
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: donor.userId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: switch (rank) {
                  1 => SvgPicture.asset(AppIcons.medalGold, width: 28),
                  2 => SvgPicture.asset(AppIcons.medalSilver, width: 28),
                  3 => SvgPicture.asset(AppIcons.medalBronze, width: 28),
                  _ => Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.appTextSecondary,
                    ),
                  ),
                },
              ),
              const SizedBox(width: 8),
              AppAvatar(radius: 24, imageUrl: donor.profile?.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name == null || name.isEmpty ? context.l10n.yourName : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${donor.count}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppIcon(AppIcons.star, size: 40, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          context.l10n.donorsEmpty,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.donorsEmptyHint,
          style: TextStyle(fontSize: 13, color: context.appTextSecondary),
        ),
      ],
    );
  }
}
