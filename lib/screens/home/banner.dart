import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/models/user/watchlist_item.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/watchlist.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/widgets/toast.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Hero banner carousel shown at the top of the Home screen.
class HeroBannerCarousel extends ConsumerStatefulWidget {
  final List<dynamic> items;
  final Map<int, String?> logos;
  final Map<int, String?> posters;

  const HeroBannerCarousel({
    super.key,
    required this.items,
    required this.logos,
    required this.posters,
  });

  @override
  ConsumerState<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends ConsumerState<HeroBannerCarousel> {
  late final PageController _pageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  int _currentBannerPage = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _bannerTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_pageController.hasClients && widget.items.isNotEmpty) {
        _pageController.animateToPage(
          _currentBannerPage + 1,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox(height: 500);

    final watchlistIds = ref.watch(watchlistProvider).map((e) => e.id).toSet();
    final aniListStatusById = ref.watch(watchlistStatusByIdProvider);

    return SizedBox(
      height: 600,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          if (index == 0) {
            setState(() {
              _currentBannerIndex = items.length - 1;
              _currentBannerPage = index;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_pageController.hasClients) return;
              _pageController.jumpToPage(items.length);
              if (mounted) setState(() => _currentBannerPage = items.length);
            });
            return;
          }
          if (index == items.length + 1) {
            setState(() {
              _currentBannerIndex = 0;
              _currentBannerPage = index;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_pageController.hasClients) return;
              _pageController.jumpToPage(1);
              if (mounted) setState(() => _currentBannerPage = 1);
            });
            return;
          }
          setState(() {
            _currentBannerPage = index;
            _currentBannerIndex = (index - 1) % items.length;
          });
        },
        itemCount: items.length + 2,
        itemBuilder: (context, index) {
          final content =
              switch (index) {
                    0 => items.last,
                    _ when index == items.length + 1 => items.first,
                    _ => items[index - 1],
                  }
                  as Map<String, dynamic>;

          final tmdbId = content['id'];
          final mediaId = (tmdbId as num?)?.toInt();
          final tvdbBackdropUrl = mediaId != null
              ? widget.posters[mediaId]
              : null;
          final backdropUrl =
              (tvdbBackdropUrl != null && tvdbBackdropUrl.isNotEmpty)
              ? tvdbBackdropUrl
              : null;
          final title = content['title'] ?? content['name'] ?? 'Featured';
          final aniListStatus = mediaId == null
              ? null
              : aniListStatusById[mediaId];
          final isPlanningOrWatching =
              aniListStatus == 'PLANNING' || aniListStatus == 'WATCHING';
          final isAlreadyInList =
              mediaId != null &&
              (watchlistIds.contains(mediaId) || isPlanningOrWatching);
          final episodeCount = (content['episode_count'] as num?)?.toInt();
          final year =
              ((content['first_air_date'] ?? content['release_date'])
                          ?.toString()
                          .split('-')
                          .first ??
                      '')
                  .trim();
          final genreIds = (content['genre_ids'] as List<dynamic>? ?? [])
              .whereType<num>()
              .map((g) => TmdbGenres.labels[g.toInt()])
              .whereType<String>()
              .take(3)
              .toList();
          final meta = [
            if (genreIds.isNotEmpty) genreIds.join(' • '),
            if (episodeCount != null && episodeCount > 0) '$episodeCount eps',
            if (year.isNotEmpty) year,
          ];

          return Stack(
            children: [
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  decoration: BoxDecoration(
                    image: backdropUrl != null && backdropUrl.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(backdropUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: backdropUrl == null ? const Color(0xFF2F2F2F) : null,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                      const Color(0xFF141414),
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 76,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Builder(
                            builder: (context) {
                              final logoUrl = mediaId != null
                                  ? widget.logos[mediaId]
                                  : null;
                              if (logoUrl != null && logoUrl.isNotEmpty) {
                                return CachedNetworkImage(
                                  imageUrl: logoUrl,
                                  height: 72,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) => Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }
                              return Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          if (meta.isNotEmpty)
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: _buildMetaChips(meta),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _smallSquareButton(
                                icon: PhosphorIcon(
                                  isAlreadyInList
                                      ? PhosphorIconsFill.bookmarkSimple
                                      : PhosphorIconsRegular.plus,
                                  color: isAlreadyInList
                                      ? NamizoTheme.primary
                                      : Colors.white,
                                  size: 18,
                                ),
                                onTap: () => _toggleFeaturedWatchlist(content),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    context.push('/media/$tmdbId?type=tv'),
                                icon: const PhosphorIcon(
                                  PhosphorIconsFill.play,
                                  color: Colors.black,
                                  size: 16,
                                ),
                                label: const Text('Play'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _smallSquareButton(
                                icon: const PhosphorIcon(
                                  PhosphorIconsRegular.info,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onTap: () =>
                                    context.push('/media/$tmdbId?type=tv'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    items.length,
                    (dotIndex) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentBannerIndex == dotIndex ? 7 : 5,
                      height: _currentBannerIndex == dotIndex ? 7 : 5,
                      decoration: BoxDecoration(
                        color: _currentBannerIndex == dotIndex
                            ? NamizoTheme.primary
                            : Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleFeaturedWatchlist(Map<String, dynamic> content) async {
    final watchlistService = ref.read(watchlistServiceProvider);
    final shouldSyncAniList =
        ref.read(aniListViewerProvider).valueOrNull != null &&
        ref.read(aniListAutoSyncProvider);
    final aniListService = ref.read(aniListServiceProvider);
    final mediaId = content['id'] as int?;
    if (mediaId == null) return;

    final localAlreadyExists = ref
        .read(watchlistProvider)
        .any((item) => item.id == mediaId);
    final aniListAlreadyExists = ref
        .read(watchlistStatusByIdProvider)
        .containsKey(mediaId);

    if (localAlreadyExists || aniListAlreadyExists) {
      if (localAlreadyExists) {
        await watchlistService.removeFromWatchlist(mediaId);
      }
      final hasAniListLogin =
          ref.read(aniListViewerProvider).valueOrNull != null;
      if (hasAniListLogin && aniListAlreadyExists) {
        await aniListService.removeFromTrackedByMalId(mediaId);
        ref.read(aniListAccountRefreshProvider.notifier).state++;
      }
      ref.read(watchlistRefreshProvider.notifier).refresh();
      ref.invalidate(watchlistProvider);
      if (!mounted) return;
      _showWatchlistToast(
        message: 'Removed from list',
        icon: PhosphorIconsRegular.bookmarkSimple,
        accent: const Color(0xFFEF4444),
      );
      return;
    }

    final item = WatchlistItem(
      id: mediaId,
      title: (content['title'] ?? content['name'] ?? 'Unknown').toString(),
      posterPath: content['poster_path']?.toString(),
      backdropPath: content['backdrop_path']?.toString(),
      mediaType: 'tv',
      addedAt: DateTime.now(),
      voteAverage: (content['vote_average'] as num?)?.toDouble(),
      releaseDate: (content['first_air_date'] ?? content['release_date'])
          ?.toString(),
      overview: content['overview']?.toString(),
    );

    await watchlistService.addToWatchlist(item);
    if (shouldSyncAniList) {
      final synced = await aniListService.addToPlanningByMalId(mediaId);
      if (synced) {
        ref.read(aniListAccountRefreshProvider.notifier).state++;
      }
    }
    ref.read(watchlistRefreshProvider.notifier).refresh();
    if (!mounted) return;

    _showWatchlistToast(
      message: 'Added to watchlist',
      icon: PhosphorIconsFill.bookmarkSimple,
      accent: const Color(0xFF22C55E),
    );
  }

  void _showWatchlistToast({
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

/// Loading placeholder for the hero banner.
class HeroBannerShimmer extends StatelessWidget {
  const HeroBannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      color: const Color(0xFF2F2F2F),
      child: const Center(
        child: CircularProgressIndicator(color: NamizoTheme.primary),
      ),
    );
  }
}

List<Widget> _buildMetaChips(List<String> meta) {
  final widgets = <Widget>[];
  for (var i = 0; i < meta.length; i++) {
    widgets.add(
      Text(
        meta[i],
        style: const TextStyle(
          color: Color(0xFFD4D8E3),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    if (i != meta.length - 1) {
      widgets.add(
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: Color(0xFFD4D8E3),
            shape: BoxShape.circle,
          ),
        ),
      );
    }
  }
  return widgets;
}

Widget _smallSquareButton({required Widget icon, required VoidCallback onTap}) {
  return Material(
    color: const Color(0x30FFFFFF),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 38, height: 38, child: Center(child: icon)),
    ),
  );
}
