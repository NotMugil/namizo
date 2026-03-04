import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/models/watchlist_item.dart';
import 'package:namizo/providers/homeproviders.dart';
import 'package:namizo/providers/serviceproviders.dart';
import 'package:namizo/providers/settingsproviders.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/providers/watchhistoryprovider.dart';
import 'package:namizo/providers/watchlistprovider.dart';
import 'package:namizo/ui/home/widgets/content_row.dart';
import 'package:namizo/ui/home/widgets/continue_watching_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const Map<int, String> _genreMap = {
    16: 'Animation',
    28: 'Action',
    12: 'Adventure',
    14: 'Fantasy',
    35: 'Comedy',
    18: 'Drama',
    9648: 'Mystery',
    878: 'Sci-Fi',
    10759: 'Action & Adventure',
    10765: 'Fantasy',
  };

  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  bool _showAppBarBackground = false;
  int _currentBannerIndex = 0;
  int _currentBannerPage = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_showAppBarBackground) {
        setState(() => _showAppBarBackground = true);
      } else if (_scrollController.offset <= 50 && _showAppBarBackground) {
        setState(() => _showAppBarBackground = false);
      }
    });

    _bannerTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_pageController.hasClients) {
        final featuredContent = ref.read(featuredAnimeProvider).value ?? [];
        if (featuredContent.isNotEmpty) {
          final nextPage = _currentBannerPage + 1;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });

    unawaited(_prewarmHomeContent());
  }

  Future<void> _prewarmHomeContent() async {
    await Future.wait([
      ref.read(featuredAnimeProvider.future),
      ref.read(popularAnimeProvider.future),
      ref.read(trendingAnimeProvider.future),
      ref.read(topRatedAnimeProvider.future),
      ref.read(romanceAnimeProvider.future),
      ref.read(actionAnimeProvider.future),
      ref.read(adventureAnimeProvider.future),
      ref.read(fantasyAnimeProvider.future),
      ref.read(featuredAnimeLogosProvider.future),
      ref.read(featuredAnimePostersProvider.future),
    ]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featuredContent = ref.watch(featuredAnimeProvider);
    final featuredLogos = ref.watch(featuredAnimeLogosProvider);
    final featuredPosters = ref.watch(featuredAnimePostersProvider);
    final aniListViewerAsync = ref.watch(aniListViewerProvider);
    final easterEggEnabled = ref.watch(easterEggHomeLogoProvider);

    // Precache logo images as soon as all URLs are resolved
    ref.listen(featuredAnimeLogosProvider, (_, next) {
      next.whenData((logos) {
        for (final url in logos.values) {
          if (url != null && url.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(url), context);
          }
        }
      });
    });

    ref.listen(featuredAnimePostersProvider, (_, next) {
      next.whenData((posters) {
        for (final url in posters.values) {
          if (url != null && url.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(url), context);
          }
        }
      });
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          backgroundColor: _showAppBarBackground
              ? Colors.transparent
              : Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _showAppBarBackground ? 12 : 0,
                sigmaY: _showAppBarBackground ? 12 : 0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _showAppBarBackground
                      ? const Color(0x6A0D0F14)
                      : Colors.transparent,
                  border: _showAppBarBackground
                      ? const Border(
                          bottom: BorderSide(color: Color(0x22FFFFFF)),
                        )
                      : null,
                  gradient: _showAppBarBackground
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                ),
              ),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4),
            child: easterEggEnabled
                ? Image.asset(
                    'assets/images/nami.png',
                    height: 26,
                    fit: BoxFit.contain,
                  )
                : const Text(
                    'Namizo.',
                    style: TextStyle(
                      color: NamizoTheme.netflixWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildNotificationBell(context),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildProfileButton(context, aniListViewerAsync),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        cacheExtent: 1000,
        slivers: [
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: featuredContent.when(
                data: (content) => _buildHeroBannerCarousel(
                  context,
                  content,
                  featuredLogos.value ?? {},
                  featuredPosters.value ?? {},
                ),
                loading: () => _buildHeroBannerShimmer(),
                error: (_, __) => const SizedBox(height: 500),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF141414), Color(0xFF0D0F14)],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final trendingAnime = ref.watch(trendingAnimeProvider);
                final trendingPosterById = <int, dynamic>{};
                trendingAnime.whenData((shows) {
                  for (final show in shows) {
                    if (show is! Map) continue;
                    final id = (show['id'] as num?)?.toInt();
                    if (id == null) continue;
                    final posterPath = show['poster_path'];
                    if (posterPath != null) {
                      trendingPosterById[id] = posterPath;
                    }
                  }
                });

                final watchlist = ref
                    .watch(watchlistProvider)
                    .where((item) => item.mediaType == 'tv')
                    .toList();
                if (watchlist.isEmpty) {
                  return const SizedBox.shrink();
                }

                final seenIds = <int>{};
                final watchlistItems = watchlist
                    .where((item) => seenIds.add(item.id))
                    .map(
                      (WatchlistItem item) => {
                        'id': item.id,
                        'name': item.title,
                        'title': item.title,
                        'poster_path':
                            trendingPosterById[item.id] ?? item.posterPath,
                        'vote_average': item.voteAverage,
                        'first_air_date': item.releaseDate,
                        'media_type': 'tv',
                      },
                    )
                    .toList(growable: false);

                return ContentRow(
                  title: 'Your List',
                  items: watchlistItems,
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final planningAsync = ref.watch(aniListPlanningProvider);
                return planningAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return ContentRow(
                      title: 'Planning to Watch',
                      items: items,
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final continueWatching = ref.watch(continueWatchingProvider);
                return continueWatching.when(
                  data: (items) {
                    if (items.length <= 1) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 0, left: 16, right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Continue Watching',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const ContinueWatchingRow(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final anime = ref.watch(popularAnimeProvider);
                return anime.when(
                  data: (shows) => ContentRow(
                    title: 'All Time Popular',
                    items: shows,
                  ),
                  loading: () => const SizedBox(height: 220),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final trendingAnime = ref.watch(trendingAnimeProvider);
                return trendingAnime.when(
                  data: (shows) => ContentRow(
                    title: 'Trending Now',
                    items: shows,
                  ),
                  loading: () => const SizedBox(height: 220),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final topRatedAnime = ref.watch(topRatedAnimeProvider);
                return topRatedAnime.when(
                  data: (shows) => ContentRow(
                    title: 'Top Rated Anime',
                    items: shows,
                  ),
                  loading: () => const SizedBox(height: 220),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final romanceAnime = ref.watch(romanceAnimeProvider);
                return romanceAnime.when(
                  data: (shows) => ContentRow(
                    title: 'Romance',
                    items: shows,
                  ),
                  loading: () => const SizedBox(height: 220),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final actionAnime = ref.watch(actionAnimeProvider);
                return actionAnime.when(
                  data: (shows) => ContentRow(
                    title: 'Action',
                    items: shows,
                  ),
                  loading: () => const SizedBox(height: 220),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final adventureAnime = ref.watch(adventureAnimeProvider);
                return adventureAnime.when(
                  data: (shows) => ContentRow(
                    title: 'Adventure',
                    items: shows,
                  ),
                  loading: () => const SizedBox(height: 220),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final fantasyAnime = ref.watch(fantasyAnimeProvider);
                return fantasyAnime.when(
                  data: (shows) => ContentRow(
                    title: 'Fantasy',
                    items: shows,
                  ),
                  loading: () => const SizedBox(height: 220),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 50),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBannerCarousel(
    BuildContext context,
    List<dynamic> items,
    Map<int, String?> logos,
    Map<int, String?> posters,
  ) {
    if (items.isEmpty) return const SizedBox(height: 500);
    final itemCount = items.length + 1;

    return SizedBox(
      height: 600,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          if (index == items.length) {
            setState(() {
              _currentBannerIndex = 0;
              _currentBannerPage = index;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_pageController.hasClients) return;
              _pageController.jumpToPage(0);
              if (mounted) {
                setState(() => _currentBannerPage = 0);
              }
            });
            return;
          }

          setState(() {
            _currentBannerPage = index;
            _currentBannerIndex = index % items.length;
          });
        },
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final content = items[index == items.length ? 0 : index];
          final tmdbId = content['id'];
          final alternativePosterUrl = tmdbId is int ? posters[tmdbId] : null;
          final posterPath = content['poster_path'];
          final fallbackPosterUrl = posterPath is String &&
                  (posterPath.startsWith('http://') ||
                      posterPath.startsWith('https://'))
              ? posterPath
              : posterPath is String && posterPath.startsWith('/')
                  ? 'https://kuroiru.co$posterPath'
                  : posterPath != null
                      ? posterPath.toString()
                      : null;
          final backdropUrl =
              (alternativePosterUrl != null && alternativePosterUrl.isNotEmpty)
                  ? alternativePosterUrl
                  : fallbackPosterUrl;
          final title = content['title'] ?? content['name'] ?? 'Featured';
            final episodeCount = (content['episode_count'] as num?)?.toInt();
            final year = ((content['first_air_date'] ?? content['release_date'])
                  ?.toString()
                  .split('-')
                  .first ??
                '')
              .trim();
            final genreIds = (content['genre_ids'] as List<dynamic>? ?? [])
              .whereType<num>()
              .map((genreId) => _genreMap[genreId.toInt()])
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
                            image: CachedNetworkImageProvider(
                              backdropUrl,
                            ),
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
                              final logoUrl =
                                  tmdbId is int ? logos[tmdbId] : null;
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
                                icon: const PhosphorIcon(
                                  PhosphorIconsRegular.plus,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onTap: () => _addFeaturedToWatchlist(content),
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
                            ? NamizoTheme.netflixRed
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

  Widget _buildHeroBannerShimmer() {
    return Container(
      height: 600,
      color: const Color(0xFF2F2F2F),
      child: const Center(
        child: CircularProgressIndicator(color: NamizoTheme.netflixRed),
      ),
    );
  }

  Widget _buildProfileButton(
    BuildContext context,
    AsyncValue<Map<String, dynamic>?> aniListViewerAsync,
  ) {
    final avatarUrl = aniListViewerAsync.valueOrNull?['avatar']?['large']
            ?.toString() ??
        aniListViewerAsync.valueOrNull?['avatar']?['medium']?.toString();

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return IconButton(
        tooltip: 'Profile',
        onPressed: () => context.go('/profile'),
        icon: CircleAvatar(
          radius: 12,
          backgroundColor: Colors.white24,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
        ),
      );
    }

    return IconButton(
      icon: const PhosphorIcon(
        PhosphorIconsRegular.userCircle,
        color: Colors.white,
        size: 24,
      ),
      tooltip: 'Profile',
      onPressed: () => context.go('/profile'),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final unreadCount = EpisodeCheckService.getUnreadCount();

    return Stack(
      children: [
        IconButton(
          icon: unreadCount > 0
              ? const PhosphorIcon(
                  PhosphorIconsFill.bellSimpleRinging,
                  color: Colors.white,
                  size: 22,
                )
              : const PhosphorIcon(
                  PhosphorIconsRegular.bell,
                  color: Colors.white,
                  size: 22,
                ),
          tooltip: 'New Episodes',
          onPressed: () => context.push('/notifications'),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFE50914),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildMetaChips(List<String> meta) {
    final widgets = <Widget>[];
    for (var index = 0; index < meta.length; index++) {
      widgets.add(
        Text(
          meta[index],
          style: const TextStyle(
            color: Color(0xFFD4D8E3),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      if (index != meta.length - 1) {
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

  Widget _smallSquareButton({
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0x30FFFFFF),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(child: icon),
        ),
      ),
    );
  }

  Future<void> _addFeaturedToWatchlist(Map<String, dynamic> content) async {
    final watchlistService = ref.read(watchlistServiceProvider);
    final mediaId = content['id'] as int?;
    if (mediaId == null) return;

    final item = WatchlistItem(
      id: mediaId,
      title: (content['title'] ?? content['name'] ?? 'Unknown').toString(),
      posterPath: content['poster_path']?.toString(),
      mediaType: 'tv',
      addedAt: DateTime.now(),
      voteAverage: (content['vote_average'] as num?)?.toDouble(),
      releaseDate: (content['first_air_date'] ?? content['release_date'])
          ?.toString(),
      overview: content['overview']?.toString(),
    );

    await watchlistService.addToWatchlist(item);
    ref.read(watchlistRefreshProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to watchlist')),
    );
  }
}
