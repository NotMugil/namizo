import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:namizo/core/user_config.dart';
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
import 'package:namizo/ui/shared/toast/app_toast.dart';

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
  final PageController _pageController = PageController(initialPage: 1);
  bool _showAppBarBackground = false;
  int _currentBannerIndex = 0;
  int _currentBannerPage = 1;
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
    final homeFeedOrder = ref.watch(homeFeedOrderProvider);
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
                data: (content) {
                  final postersReady =
                      featuredPosters.hasValue &&
                      !featuredPosters.isLoading &&
                      (featuredPosters.valueOrNull?.isNotEmpty ?? false);

                  if (!postersReady) {
                    return _buildHeroBannerShimmer();
                  }

                  return _buildHeroBannerCarousel(
                    context,
                    content,
                    featuredLogos.value ?? {},
                    featuredPosters.valueOrNull ?? const <int, String?>{},
                  );
                },
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
          ..._buildOrderedFeedRowSlivers(
            context,
            ref,
            homeFeedOrder,
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
    final watchlistIds = ref
        .watch(watchlistProvider)
        .map((item) => item.id)
        .toSet();
    final aniListStatusById = ref.watch(watchlistStatusByIdProvider);
    final itemCount = items.length + 2;

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
              if (mounted) {
                setState(() => _currentBannerPage = items.length);
              }
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
              if (mounted) {
                setState(() => _currentBannerPage = 1);
              }
            });
            return;
          }

          setState(() {
            _currentBannerPage = index;
            _currentBannerIndex = (index - 1) % items.length;
          });
        },
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final content = switch (index) {
            0 => items.last,
            _ when index == items.length + 1 => items.first,
            _ => items[index - 1],
          };
          final tmdbId = content['id'];
          final tvdbBackdropUrl = tmdbId is int ? posters[tmdbId] : null;
          final backdropUrl =
            (tvdbBackdropUrl != null && tvdbBackdropUrl.isNotEmpty)
              ? tvdbBackdropUrl
              : null;
          final title = content['title'] ?? content['name'] ?? 'Featured';
            final mediaId = (tmdbId as num?)?.toInt();
            final aniListStatus = mediaId == null ? null : aniListStatusById[mediaId];
            final isPlanningOrWatching =
              aniListStatus == 'PLANNING' || aniListStatus == 'WATCHING';
            final isAlreadyInList =
              mediaId != null && (watchlistIds.contains(mediaId) || isPlanningOrWatching);
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
                                icon: PhosphorIcon(
                                  isAlreadyInList
                                      ? PhosphorIconsFill.bookmarkSimple
                                      : PhosphorIconsRegular.plus,
                                  color: isAlreadyInList
                                      ? NamizoTheme.netflixRed
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

  List<Widget> _buildOrderedFeedRowSlivers(
    BuildContext context,
    WidgetRef ref,
    List<String> order,
  ) {
    final normalized = order.isEmpty
        ? UserConfig.defaultHomeFeedOrder
        : order;

    final slivers = <Widget>[];
    for (final key in normalized) {
      final sliver = _buildFeedSliverForKey(context, key);
      if (sliver != null) {
        slivers.add(sliver);
      }
    }
    return slivers;
  }

  Widget? _buildFeedSliverForKey(BuildContext context, String key) {
    switch (key) {
      case 'popular':
        return _buildAsyncRowSliver(
          provider: popularAnimeProvider,
          title: 'All Time Popular',
          searchQuery: 'all time popular anime',
        );
      case 'trending':
        return _buildAsyncRowSliver(
          provider: trendingAnimeProvider,
          title: 'Trending Now',
          searchQuery: 'trending anime',
        );
      case 'topRated':
        return _buildAsyncRowSliver(
          provider: topRatedAnimeProvider,
          title: 'Top Rated Anime',
          searchQuery: 'top rated anime',
        );
      case 'romance':
        return _buildAsyncRowSliver(
          provider: romanceAnimeProvider,
          title: 'Romance',
          searchQuery: 'romance anime',
        );
      case 'action':
        return _buildAsyncRowSliver(
          provider: actionAnimeProvider,
          title: 'Action',
          searchQuery: 'action anime',
        );
      case 'adventure':
        return _buildAsyncRowSliver(
          provider: adventureAnimeProvider,
          title: 'Adventure',
          searchQuery: 'adventure anime',
        );
      case 'fantasy':
        return _buildAsyncRowSliver(
          provider: fantasyAnimeProvider,
          title: 'Fantasy',
          searchQuery: 'fantasy anime',
        );
      default:
        return null;
    }
  }

  Widget _buildAsyncRowSliver({
    required FutureProvider<List<dynamic>> provider,
    required String title,
    required String searchQuery,
  }) {
    return SliverToBoxAdapter(
      child: Consumer(
        builder: (context, ref, child) {
          final asyncValue = ref.watch(provider);
          return asyncValue.when(
            data: (shows) => ContentRow(
              title: title,
              items: shows,
              onSeeMore: () {
                final encoded = Uri.encodeQueryComponent(searchQuery);
                context.go('/search?q=$encoded');
              },
            ),
            loading: () => const SizedBox(height: 220),
            error: (_, __) => const SizedBox.shrink(),
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
