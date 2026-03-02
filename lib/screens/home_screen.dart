import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, List, Map, Timer, Navigator, Page, Radius;
import 'package:namizo/core/constants.dart';
import 'package:namizo/core/theme.dart';
import 'package:namizo/models/watchlist_item.dart';
import 'package:namizo/providers/home_providers.dart';
import 'package:namizo/services/episode_check_service.dart';
import 'package:namizo/providers/watchlist_provider.dart';
import 'package:namizo/widgets/content_row.dart';
import 'package:namizo/widgets/continue_watching_row.dart';

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
          final nextPage = (_currentBannerIndex + 1) % featuredContent.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
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
          title: const Padding(
            padding: EdgeInsets.only(top: 8.0, left: 4),
            child: Text(
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
              child: IconButton(
                icon: const UserCircle(color: Colors.white, width: 24, height: 24),
                tooltip: 'Profile',
                onPressed: () => context.go('/profile'),
              ),
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
                data: (content) => _buildHeroBannerCarousel(context, content),
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
            child: Padding(
              padding: const EdgeInsets.only(top: 0, left: 16, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue Watching',
                    style: const TextStyle(
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
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) {
                final anime = ref.watch(popularAnimeProvider);
                return anime.when(
                  data: (shows) => ContentRow(
                    title: 'Popular Anime',
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
                    title: 'Trending Anime',
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
          const SliverToBoxAdapter(
            child: SizedBox(height: 50),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBannerCarousel(BuildContext context, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox(height: 500);

    return SizedBox(
      height: 600,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentBannerIndex = index);
        },
        itemCount: items.length,
        itemBuilder: (context, index) {
          final content = items[index];
          final backdropPath = content['backdrop_path'] ?? content['poster_path'];
          final title = content['title'] ?? content['name'] ?? 'Featured';
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
            '24 min',
            if (year.isNotEmpty) year,
            ];
          final tmdbId = content['id'];

          return Stack(
            children: [
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  decoration: BoxDecoration(
                    image: backdropPath != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                              '$tmdbImageBaseUrl/$backdropSize$backdropPath',
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: backdropPath == null ? const Color(0xFF2F2F2F) : null,
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
                          Text(
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
                                icon: const Plus(
                                  color: Colors.white,
                                  width: 18,
                                  height: 18,
                                ),
                                onTap: () => _addFeaturedToWatchlist(content),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    context.push('/media/$tmdbId?type=tv'),
                                icon: const Play(
                                  color: Colors.black,
                                  width: 16,
                                  height: 16,
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
                                icon: const InfoCircle(
                                  color: Colors.white,
                                  width: 18,
                                  height: 18,
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
                            ? const Color(0xFF9D96FF)
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
        child: CircularProgressIndicator(color: Color(0xFF9D96FF)),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final unreadCount = EpisodeCheckService.getUnreadCount();

    return Stack(
      children: [
        IconButton(
          icon: unreadCount > 0
              ? const BellNotification(color: Colors.white, width: 22, height: 22)
              : const Bell(color: Colors.white, width: 22, height: 22),
          tooltip: 'New Episodes',
          onPressed: () => context.go('/calendar'),
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
