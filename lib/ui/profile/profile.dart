import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namizo/providers/serviceproviders.dart';
import 'package:namizo/providers/watchlistprovider.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aniListViewerAsync = ref.watch(aniListViewerProvider);

    return aniListViewerAsync.when(
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

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: NamizoTheme.netflixBlack,
            body: Column(
              children: [
                _buildProfileHeader(context, viewer),
                const TabBar(
                  indicatorColor: NamizoTheme.netflixRed,
                  dividerColor: Colors.transparent,
                  labelColor: NamizoTheme.netflixWhite,
                  unselectedLabelColor: NamizoTheme.netflixGrey,
                  tabs: [
                    Tab(
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.chartBar,
                        size: 20,
                      ),
                    ),
                    Tab(
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.bookmarkSimple,
                        size: 20,
                      ),
                    ),
                    Tab(
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.pulse,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildStatsTab(viewer),
                      _buildWatchlistTab(context, ref),
                      _buildActivitiesTab(ref),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final avatarUrl = avatar?['large']?.toString() ?? avatar?['medium']?.toString();

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
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => context.push('/settings'),
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.gear,
                  color: NamizoTheme.netflixWhite,
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

  Widget _buildStatsTab(Map<String, dynamic> viewer) {
    final statistics = viewer['statistics'] as Map<String, dynamic>?;
    final animeStats = statistics?['anime'] as Map<String, dynamic>?;

    final entries = [
      _StatItem('Anime Count', _toDisplayValue(animeStats?['count'])),
      _StatItem(
        'Episodes Watched',
        _toDisplayValue(animeStats?['episodesWatched']),
      ),
      _StatItem(
        'Minutes Watched',
        _toDisplayValue(animeStats?['minutesWatched']),
      ),
      _StatItem('Mean Score', _toDisplayValue(animeStats?['meanScore'])),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entries[index].label,
                style: const TextStyle(
                  color: NamizoTheme.netflixLightGrey,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              entries[index].value,
              style: const TextStyle(
                color: NamizoTheme.netflixWhite,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: entries.length,
    );
  }

  Widget _buildWatchlistTab(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final tmdbService = ref.watch(kuroiruServiceProvider);

    if (watchlist.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your watchlist is empty',
            style: TextStyle(
              color: NamizoTheme.netflixGrey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: watchlist.length,
      itemBuilder: (context, index) {
        final item = watchlist[index];
        final posterUrl = tmdbService.getPosterUrl(item.posterPath);

        return InkWell(
          onTap: () => context.push('/media/${item.id}?type=${item.mediaType}'),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: const Color(0x29222A3C),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: NamizoTheme.netflixRed,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0x29222A3C),
                            child: const Center(
                                      child: PhosphorIcon(
                                        PhosphorIconsRegular.imageBroken,
                                color: NamizoTheme.netflixGrey,
                                        size: 20,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0x29222A3C),
                          child: const Center(
                                    child: PhosphorIcon(
                                      PhosphorIconsRegular.video,
                              color: NamizoTheme.netflixGrey,
                                      size: 20,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NamizoTheme.netflixWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivitiesTab(WidgetRef ref) {
    final activitiesAsync = ref.watch(aniListActivitiesProvider);

    return activitiesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NamizoTheme.netflixRed),
      ),
      error: (_, __) => const Center(
        child: Text(
          'Unable to load activities',
          style: TextStyle(color: NamizoTheme.netflixGrey),
        ),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return const Center(
            child: Text(
              'No activities found',
              style: TextStyle(color: NamizoTheme.netflixGrey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final activity = activities[index];
            final media = activity['media'] as Map<String, dynamic>?;
            final title = ((media?['title'] as Map<String, dynamic>?)?['userPreferred'] ??
                    'Unknown title')
                .toString();
            final coverUrl =
                ((media?['coverImage'] as Map<String, dynamic>?)?['large'])?.toString();
            final status = (activity['status'] ?? 'Updated').toString();
            final progress = (activity['progress'] ?? '').toString();
            final createdAt = activity['createdAt'] as int?;

            final subtitle = [
              '$status ${progress.trim()}'.trim(),
              if (createdAt != null)
                DateFormat.yMMMd().add_jm().format(
                      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
                    ),
            ].join(' • ');

            return Container(
              decoration: BoxDecoration(
                color: const Color(0x1FFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 60,
                    child: (coverUrl != null && coverUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(color: NamizoTheme.netflixDarkGrey),
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NamizoTheme.netflixWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NamizoTheme.netflixGrey),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _toDisplayValue(dynamic value) {
    if (value == null) return '-';
    return value.toString();
  }
}

class _StatItem {
  const _StatItem(this.label, this.value);

  final String label;
  final String value;
}
