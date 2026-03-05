import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/providers/serviceproviders.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/ui/shared/toast/app_toast.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final Set<int> _updatingMediaIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final aniListViewerAsync = ref.watch(aniListViewerProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: aniListViewerAsync.when(
        loading: () => const Scaffold(
          backgroundColor: NamizoTheme.netflixBlack,
          body: Center(
            child: CircularProgressIndicator(color: NamizoTheme.netflixRed),
          ),
        ),
        error: (_, __) => _buildLoggedOutView(context, ref),
        data: (viewer) {
          if (viewer == null) {
            return _buildLoggedOutView(context, ref);
          }

          final username = (viewer['name'] ?? 'AniList User').toString();
          final avatar = viewer['avatar'] as Map<String, dynamic>?;
          final avatarUrl =
              avatar?['large']?.toString() ?? avatar?['medium']?.toString();

          return Scaffold(
            backgroundColor: NamizoTheme.netflixBlack,
            body: Column(
              children: [
                _buildProfileHeader(context, viewer),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    children: [
                      _buildStatsSection(viewer),
                      const SizedBox(height: 2),
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          color: NamizoTheme.netflixWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildActivitiesSection(
                        username: username,
                        avatarUrl: avatarUrl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoggedOutView(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NamizoTheme.netflixBlack,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please login to use this feature',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NamizoTheme.netflixWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 190,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NamizoTheme.netflixRed,
                    foregroundColor: NamizoTheme.netflixWhite,
                    minimumSize: const Size(190, 48),
                  ),
                  onPressed: () async {
                    final result = await context.push<bool>('/anilist-login');
                    if (result == true) {
                      ref.read(aniListAccountRefreshProvider.notifier).state++;
                    }
                  },
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: NamizoTheme.netflixRed,
                  minimumSize: const Size(190, 44),
                ),
                onPressed: () => context.push('/settings'),
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.gear,
                  size: 18,
                  color: NamizoTheme.netflixRed,
                ),
                label: const Text('Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    Map<String, dynamic> viewer,
  ) {
    final name = (viewer['name'] ?? 'AniList User').toString();
    final bannerUrl = viewer['bannerImage']?.toString();
    final avatar = viewer['avatar'] as Map<String, dynamic>?;
    final avatarUrl =
        avatar?['large']?.toString() ?? avatar?['medium']?.toString();

    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bannerUrl != null && bannerUrl.isNotEmpty)
            CachedNetworkImage(imageUrl: bannerUrl, fit: BoxFit.cover)
          else
            Container(color: NamizoTheme.netflixDarkGrey),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x70000000), Color(0xE6000000)],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => context.go('/home'),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.caretLeft,
                        color: NamizoTheme.netflixWhite,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/settings'),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.gear,
                        color: NamizoTheme.netflixWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: NamizoTheme.netflixDarkGrey,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const PhosphorIcon(
                          PhosphorIconsRegular.userCircle,
                          color: NamizoTheme.netflixWhite,
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: NamizoTheme.netflixWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> viewer) {
    final statistics = viewer['statistics'] as Map<String, dynamic>?;
    final animeStats = statistics?['anime'] as Map<String, dynamic>?;

    final entries = <_StatItem>[
      _StatItem(
        icon: PhosphorIconsFill.televisionSimple,
        label: 'Anime',
        value: _toDisplayValue(animeStats?['count']),
      ),
      _StatItem(
        icon: PhosphorIconsFill.playCircle,
        label: 'Episodes',
        value: _toDisplayValue(animeStats?['episodesWatched']),
      ),
      _StatItem(
        icon: PhosphorIconsFill.clock,
        label: 'Minutes',
        value: _toDisplayValue(animeStats?['minutesWatched']),
      ),
      _StatItem(
        icon: PhosphorIconsFill.star,
        label: 'Mean Score',
        value: _toDisplayValue(animeStats?['meanScore']),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 0,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final item = entries[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhosphorIcon(
                item.icon,
                color: NamizoTheme.netflixRed,
                size: 15,
              ),
              const SizedBox(height: 8),
              Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NamizoTheme.netflixWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NamizoTheme.netflixLightGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildActivitiesSection({
    required String username,
    required String? avatarUrl,
  }) {
    final activitiesAsync = ref.watch(aniListActivitiesProvider);

    return activitiesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(color: NamizoTheme.netflixRed),
        ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Unable to load activities',
            style: TextStyle(color: NamizoTheme.netflixGrey),
          ),
        ),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No activities found',
                style: TextStyle(color: NamizoTheme.netflixGrey),
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: activities.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _buildActivityCard(
              activity: activity,
              username: username,
              avatarUrl: avatarUrl,
            );
          },
        );
      },
    );
  }

  Widget _buildActivityCard({
    required Map<String, dynamic> activity,
    required String username,
    required String? avatarUrl,
  }) {
    final media = activity['media'] as Map<String, dynamic>?;
    final mediaId = (media?['id'] as num?)?.toInt();
    final title =
        ((media?['title'] as Map<String, dynamic>?)?['userPreferred'] ??
                'Unknown title')
            .toString();
    final coverUrl =
        ((media?['coverImage'] as Map<String, dynamic>?)?['large'])?.toString();
    final createdAt = (activity['createdAt'] as num?)?.toInt();
    final user = activity['user'] as Map<String, dynamic>?;
    final activityUsername =
      (user?['name']?.toString().trim().isNotEmpty == true)
      ? user!['name'].toString().trim()
      : username;
    final activityAvatar = user?['avatar'] as Map<String, dynamic>?;
    final activityAvatarUrl =
      activityAvatar?['large']?.toString() ??
      activityAvatar?['medium']?.toString() ??
      avatarUrl;
    final statusRaw = (activity['status'] ?? '').toString();
    final statusNormalized = _statusFromActivity(statusRaw);
    final progress = (activity['progress'] ?? '').toString().trim();
    final actionText = _activityActionText(statusNormalized, progress);
    final isUpdating = mediaId != null && _updatingMediaIds.contains(mediaId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: NamizoTheme.netflixDarkGrey,
                backgroundImage:
                  (activityAvatarUrl != null && activityAvatarUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(activityAvatarUrl)
                    : null,
                child: (activityAvatarUrl == null || activityAvatarUrl.isEmpty)
                    ? const PhosphorIcon(
                        PhosphorIconsRegular.user,
                        color: NamizoTheme.netflixWhite,
                        size: 11,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  activityUsername,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NamizoTheme.netflixWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '•',
                style: TextStyle(color: NamizoTheme.netflixGrey, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                _relativeTime(createdAt),
                style: const TextStyle(
                  color: NamizoTheme.netflixGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: (coverUrl != null && coverUrl.isNotEmpty)
                      ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover)
                      : Container(color: NamizoTheme.netflixDarkGrey),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actionText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NamizoTheme.netflixLightGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NamizoTheme.netflixWhite,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: (mediaId == null || isUpdating)
                          ? null
                          : () => _showStatusSelector(
                                mediaId: mediaId,
                                currentStatus: statusNormalized,
                              ),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: NamizoTheme.netflixRed.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUpdating)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: NamizoTheme.netflixRed,
                                ),
                              )
                            else
                              Text(
                                _statusLabel(statusNormalized),
                                style: const TextStyle(
                                  color: NamizoTheme.netflixWhite,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(width: 6),
                            const PhosphorIcon(
                              PhosphorIconsRegular.caretDown,
                              color: NamizoTheme.netflixWhite,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _showStatusSelector({
    required int mediaId,
    required String currentStatus,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        const options = <String>[
          'CURRENT',
          'PLANNING',
          'COMPLETED',
          'DROPPED',
          'PAUSED',
          'REPEATING',
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Change status',
                    style: TextStyle(
                      color: NamizoTheme.netflixWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...options.map((status) {
                  final selected = currentStatus == status;
                  return ListTile(
                    dense: true,
                    onTap: () => Navigator.of(context).pop(status),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: selected
                        ? const PhosphorIcon(
                            PhosphorIconsFill.checkCircle,
                            color: NamizoTheme.netflixRed,
                            size: 18,
                          )
                        : const SizedBox(width: 18),
                    title: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: selected
                            ? NamizoTheme.netflixWhite
                            : NamizoTheme.netflixLightGrey,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || selected == currentStatus) return;

    setState(() => _updatingMediaIds.add(mediaId));
    final ok = await ref.read(aniListServiceProvider).updateStatusByMediaId(
          mediaId: mediaId,
          status: selected,
        );
    if (!mounted) return;

    setState(() => _updatingMediaIds.remove(mediaId));

    if (ok) {
      ref.read(aniListAccountRefreshProvider.notifier).state++;
      _showToast(
        message: 'Status updated to ${_statusLabel(selected)}',
        icon: PhosphorIconsFill.checkCircle,
        accent: const Color(0xFF22C55E),
      );
    } else {
      _showToast(
        message: 'Failed to update status',
        icon: PhosphorIconsRegular.warning,
        accent: const Color(0xFFF59E0B),
      );
    }
  }

  String _relativeTime(int? createdAtSeconds) {
    if (createdAtSeconds == null || createdAtSeconds <= 0) return 'just now';
    final created = DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000);
    final diff = DateTime.now().difference(created);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) {
      final value = diff.inMinutes;
      return '$value minute${value == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final value = diff.inHours;
      return '$value hour${value == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 30) {
      final value = diff.inDays;
      return '$value day${value == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 365) {
      final value = (diff.inDays / 30).floor();
      return '$value month${value == 1 ? '' : 's'} ago';
    }

    final value = (diff.inDays / 365).floor();
    return '$value year${value == 1 ? '' : 's'} ago';
  }

  String _statusFromActivity(String raw) {
    final status = raw.toLowerCase();
    if (status.contains('dropped')) return 'DROPPED';
    if (status.contains('complete')) return 'COMPLETED';
    if (status.contains('paused')) return 'PAUSED';
    if (status.contains('repeat')) return 'REPEATING';
    if (status.contains('plan')) return 'PLANNING';
    return 'CURRENT';
  }

  String _activityActionText(String status, String progress) {
    switch (status) {
      case 'PLANNING':
        return 'Plans to watch';
      case 'COMPLETED':
        return 'Completed';
      case 'DROPPED':
        return 'Dropped';
      case 'PAUSED':
        return 'Paused';
      case 'REPEATING':
        return 'Rewatching';
      case 'CURRENT':
      default:
        if (progress.isNotEmpty) {
          return 'Watching $progress';
        }
        return 'Watching';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'CURRENT':
        return 'Watching';
      case 'PLANNING':
        return 'Planning';
      case 'COMPLETED':
        return 'Completed';
      case 'DROPPED':
        return 'Dropped';
      case 'PAUSED':
        return 'Paused';
      case 'REPEATING':
        return 'Rewatching';
      default:
        return status;
    }
  }

  String _toDisplayValue(dynamic value) {
    if (value == null) return '-';
    return value.toString();
  }

  void _showToast({
    required String message,
    required IconData icon,
    required Color accent,
  }) {
    AppToast.show(
      context: context,
      message: message,
      icon: icon,
      accent: accent,
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}
